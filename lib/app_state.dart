import 'dart:async';
import 'dart:convert';
import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import 'models/capability.dart';
import 'models/machine.dart';
import 'models/protocol_kind.dart';
import 'models/ssh_key.dart';
import 'protocols/protocol_registry.dart';
import 'protocols/remote_session.dart';
import 'protocols/ssh/ssh_keygen.dart';
import 'protocols/ssh/openssh_key.dart';
import 'security/secure_store.dart';
import 'security/vault.dart';

/// The single state object for the whole app. Created once above
/// [MaterialApp] — a window resize swaps layout but never touches this,
/// so sessions and selections survive.
class AppState extends ChangeNotifier {
  AppState._({
    required this._prefs,
    required this._secrets,
  }) {
    registry = ProtocolRegistry(
      keyLoader: (id) => _secrets.read('key:$id'),
      hostKeyVerifier: verifyHostKey,
    );
  }

  /// Testing-friendly constructor: inject both stores.
  static Future<AppState> load({
    SharedPreferences? prefs,
    SecretStore? secrets,
  }) async {
    final p = prefs ?? await SharedPreferences.getInstance();
    final state = AppState._(prefs: p, secrets: secrets ?? FlutterSecretStore());

    final rawMachines = p.getString('machines');
    if (rawMachines != null) {
      for (final m in jsonDecode(rawMachines) as List) {
        state._machines.add(Machine.fromJson(m as Map<String, dynamic>));
      }
    }
    final rawKeys = p.getString('keys');
    if (rawKeys != null) {
      for (final k in jsonDecode(rawKeys) as List) {
        state._keys.add(SshKeyMeta.fromJson(k as Map<String, dynamic>));
      }
    }
    return state;
  }

  final SharedPreferences _prefs;
  final SecretStore _secrets;
  final _uuid = const Uuid();

  late final ProtocolRegistry registry;

  final List<Machine> _machines = [];
  final List<SshKeyMeta> _keys = [];
  final Map<String, RemoteSession> _sessions = {};
  final Map<String, StreamSubscription> _sessionSubs = {};

  /// Decrypted secret caches for locked machines that have been opened
  /// this run, plus the derived key so edits can re-encrypt without
  /// re-asking the password.
  final Map<String, Map<String, String>> _unlocked = {};
  final Map<String, SecretKey> _unlockedKeys = {};

  List<Machine> get machines => List.unmodifiable(_machines);
  List<SshKeyMeta> get keys => List.unmodifiable(_keys);
  Map<String, RemoteSession> get sessions => Map.unmodifiable(_sessions);

  // ---- navigation (kept here so a resize never loses selection) -------

  int _navIndex = 0;
  String? _selectedMachineId;

  int get navIndex => _navIndex;
  set navIndex(int v) {
    if (_navIndex != v) {
      _navIndex = v;
      notifyListeners();
    }
  }

  String? get selectedMachineId => _selectedMachineId;
  set selectedMachineId(String? v) {
    if (_selectedMachineId != v) {
      _selectedMachineId = v;
      notifyListeners();
    }
  }

  // ---- machines --------------------------------------------------------

  Machine? machineById(String id) {
    for (final m in _machines) {
      if (m.id == id) return m;
    }
    return null;
  }

  Future<Machine> addMachine({required String name, required String host}) async {
    final m = Machine(id: _uuid.v4(), name: name, host: host);
    _machines.add(m);
    await _persistMachines();
    return m;
  }

  Future<void> updateMachine(Machine machine) async {
    final i = _machines.indexWhere((m) => m.id == machine.id);
    if (i < 0) return;
    _machines[i] = machine;
    await _persistMachines();
  }

  Future<void> removeMachine(String id) async {
    _machines.removeWhere((m) => m.id == id);
    _unlocked.remove(id);
    _unlockedKeys.remove(id);
    await _secrets.write('m:$id:secrets', null);
    await disconnect('ssh:$id');
    await disconnect('vnc:$id');
    await _persistMachines();
  }

  Future<void> _persistMachines() async {
    await _prefs.setString(
        'machines', jsonEncode(_machines.map((m) => m.toJson()).toList()));
    notifyListeners();
  }

  // ---- machine vault ---------------------------------------------------

  bool isUnlocked(String machineId) =>
      _unlocked.containsKey(machineId) ||
      !(machineById(machineId)?.locked ?? false);

  /// Raw secret map for a machine. Throws [VaultLockedException] if the
  /// machine is locked and hasn't been opened this session.
  Future<Map<String, String>> secretsFor(String machineId) async {
    final m = machineById(machineId);
    if (m == null) return {};
    if (!m.locked) {
      final raw = await _secrets.read('m:$machineId:secrets');
      return raw == null ? {} : Vault.decodePlain(raw);
    }
    final cached = _unlocked[machineId];
    if (cached == null) throw const VaultLockedException();
    return cached;
  }

  /// Unlock a password-protected machine. Returns false on a wrong
  /// password.
  Future<bool> unlockMachine(String machineId, String password) async {
    final m = machineById(machineId);
    if (m == null || !m.locked) return true;
    final salt = base64Decode(m.kdfSalt ?? '');
    final blob = await _secrets.read('m:$machineId:secrets');
    if (blob == null) {
      _unlocked[machineId] = {};
      notifyListeners();
      return true;
    }
    try {
      final key = await Vault.deriveKey(password, salt);
      _unlocked[machineId] = await Vault.unwrapWithKey(blob, key);
      _unlockedKeys[machineId] = key;
      notifyListeners();
      return true;
    } on VaultLockedException {
      return false;
    }
  }

  /// Drop the decrypted cache and key for a locked machine.
  void lockMachine(String machineId) {
    _unlocked.remove(machineId);
    _unlockedKeys.remove(machineId);
    notifyListeners();
  }

  /// Turn password protection on. Existing secrets are re-wrapped under
  /// the password.
  Future<void> setMachineLock(String machineId, String password) async {
    final m = machineById(machineId);
    if (m == null || m.locked) return;
    final salt = Vault.newSalt();
    final secrets = await secretsFor(machineId);
    final key = await Vault.deriveKey(password, salt);
    final blob = await Vault.wrapWithKey(secrets, key);
    await _secrets.write('m:$machineId:secrets', blob);
    m.locked = true;
    m.kdfSalt = base64Encode(salt);
    _unlocked[machineId] = secrets;
    _unlockedKeys[machineId] = key;
    await _persistMachines();
  }

  /// Turn password protection off. Returns false on a wrong password.
  Future<bool> removeMachineLock(String machineId, String password) async {
    final m = machineById(machineId);
    if (m == null || !m.locked) return true;
    if (!await unlockMachine(machineId, password)) return false;
    final secrets = _unlocked[machineId]!;
    await _secrets.write('m:$machineId:secrets', Vault.encodePlain(secrets));
    m.locked = false;
    m.kdfSalt = null;
    _unlocked.remove(machineId);
    _unlockedKeys.remove(machineId);
    await _persistMachines();
    return true;
  }

  /// Set or clear one secret on a machine. For locked machines the
  /// vault must already be unlocked — the cached key re-encrypts the
  /// blob.
  Future<void> setSecret(String machineId, String name, String? value) async {
    final m = machineById(machineId);
    if (m == null) return;
    final secrets = await secretsFor(machineId);
    if (value == null || value.isEmpty) {
      secrets.remove(name);
    } else {
      secrets[name] = value;
    }
    if (m.locked) {
      final key = _unlockedKeys[machineId];
      if (key == null) throw const VaultLockedException();
      await _secrets.write(
          'm:${m.id}:secrets', await Vault.wrapWithKey(secrets, key));
    } else {
      await _secrets.write(
          'm:${m.id}:secrets', Vault.encodePlain(secrets));
    }
    notifyListeners();
  }

  // ---- SSH keys --------------------------------------------------------

  SshKeyMeta? keyById(String id) {
    for (final k in _keys) {
      if (k.id == id) return k;
    }
    return null;
  }

  Future<SshKeyMeta> generateKey(SshKeyType type, String name) async {
    final id = _uuid.v4();
    final generated = type == SshKeyType.ed25519
        ? await SshKeyGen.ed25519(id, name)
        : await SshKeyGen.rsa(id, name);
    await _secrets.write('key:$id', generated.privatePem);
    _keys.add(generated.meta);
    await _persistKeys();
    return generated.meta;
  }

  /// Import an unencrypted `OPENSSH PRIVATE KEY` PEM.
  Future<SshKeyMeta> importKey(String pem, {String? name}) async {
    final meta = OpenSshKey.parsePrivateKey(pem);
    meta.id = _uuid.v4();
    if (name != null && name.isNotEmpty) meta.name = name;
    await _secrets.write('key:${meta.id}', pem);
    _keys.add(meta);
    await _persistKeys();
    return meta;
  }

  Future<void> removeKey(String id) async {
    _keys.removeWhere((k) => k.id == id);
    await _secrets.write('key:$id', null);
    await _secrets.write('key:$id:pp', null);
    // Detach from any machine that referenced it.
    for (final m in _machines) {
      final c = m.configFor(ProtocolKind.ssh) as SshConfig;
      if (c.keyId == id) {
        c.keyId = null;
        c.auth = SshAuth.password;
      }
    }
    await _persistKeys();
    await _persistMachines();
  }

  Future<String?> privateKeyPem(String id) => _secrets.read('key:$id');

  Future<void> setKeyPassphrase(String id, String? passphrase) =>
      _secrets.write('key:$id:pp', passphrase?.isEmpty ?? true ? null : passphrase);

  Future<String?> keyPassphrase(String id) => _secrets.read('key:$id:pp');

  Future<void> _persistKeys() async {
    await _prefs.setString(
        'keys', jsonEncode(_keys.map((k) => k.toJson()).toList()));
    notifyListeners();
  }

  // ---- known hosts -----------------------------------------------------

  Map<String, String> get knownHosts {
    final raw = _prefs.getString('hostkeys');
    if (raw == null) return {};
    return Map<String, String>.from(jsonDecode(raw) as Map);
  }

  Future<void> forgetHostKey(String host) async {
    final map = knownHosts..remove(host);
    await _prefs.setString('hostkeys', jsonEncode(map));
    notifyListeners();
  }

  /// Trust-on-first-use host key check. A changed fingerprint refuses
  /// the connection — that is the only useful signal SSH gives you.
  bool verifyHostKey(String host, String type, String fingerprint) {
    final map = knownHosts;
    final stored = map[host];
    if (stored == null) {
      map[host] = '$type $fingerprint';
      _prefs.setString('hostkeys', jsonEncode(map));
      notifyListeners();
      return true;
    }
    return stored == '$type $fingerprint';
  }

  // ---- sessions ---------------------------------------------------------

  String sessionId(String machineId, ProtocolKind kind) => '${kind.name}:$machineId';

  RemoteSession? sessionFor(String machineId, ProtocolKind kind) =>
      _sessions[sessionId(machineId, kind)];

  /// Open a session to [machine] over [kind]. Throws
  /// [VaultLockedException] if the machine is locked and not yet
  /// unlocked.
  Future<RemoteSession> connect(Machine machine, ProtocolKind kind) async {
    final id = sessionId(machine.id, kind);
    final existing = _sessions[id];
    if (existing != null) {
      if (existing.phase == SessionPhase.connected ||
          existing.phase == SessionPhase.connecting) {
        return existing;
      }
      // Failed or closed: drop the dead session so a retry starts
      // from a clean socket instead of reusing a broken one.
      await disconnect(id);
    }
    final secrets = await secretsFor(machine.id);
    if (kind == ProtocolKind.ssh) {
      final cfg = machine.configFor(ProtocolKind.ssh) as SshConfig;
      if (cfg.keyId != null) {
        final pp = await keyPassphrase(cfg.keyId!);
        if (pp != null) secrets['ssh.keyPassphrase'] = pp;
      }
    }
    final session = await registry.driverFor(kind).connect(machine, secrets);
    _sessions[id] = session;
    _sessionSubs[id]?.cancel();
    _sessionSubs[id] = session.status.listen((s) {
      if (s.phase == SessionPhase.closed || s.phase == SessionPhase.failed) {
        // Keep the object so the UI can show the failure, but let a
        // retry replace it.
        notifyListeners();
      }
    });
    notifyListeners();
    return session;
  }

  Future<void> disconnect(String sessionId) async {
    final sub = _sessionSubs.remove(sessionId);
    unawaited(sub?.cancel());
    final s = _sessions.remove(sessionId);
    if (s != null) {
      await s.dispose();
      notifyListeners();
    }
  }

  Future<void> disconnectAll() async {
    for (final id in _sessions.keys.toList()) {
      await disconnect(id);
    }
  }
}
