import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vsp/app_state.dart';
import 'package:vsp/models/capability.dart';
import 'package:vsp/models/protocol_kind.dart';
import 'package:vsp/models/ssh_key.dart';
import 'package:vsp/protocols/remote_session.dart';
import 'package:vsp/protocols/vnc/vnc_driver.dart';
import 'package:vsp/security/secure_store.dart';
import 'package:vsp/security/vault.dart';

import 'rfb_client_test.dart' show FakeRfbServer;

Future<AppState> _state({MemorySecretStore? store}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  return AppState.load(prefs: prefs, secrets: store ?? MemorySecretStore());
}

void main() {
  group('machines', () {
    test('add/list/update/remove', () async {
      final s = await _state();
      final m = await s.addMachine(name: 'box', host: '10.0.0.2');
      expect(s.machines, hasLength(1));
      expect(s.machineById(m.id)!.name, 'box');
      expect(s.machineById('nope'), isNull);

      m.group = 'prod';
      await s.updateMachine(m);
      expect(s.machineById(m.id)!.group, 'prod');

      await s.removeMachine(m.id);
      expect(s.machines, isEmpty);
    });

    test('persists across reloads', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final store = MemorySecretStore();
      var s = await AppState.load(prefs: prefs, secrets: store);
      final m = await s.addMachine(name: 'box', host: 'h');
      m.capabilities[ProtocolKind.vnc]!.enabled = true;
      await s.updateMachine(m);
      await s.setSecret(m.id, 'vnc.password', 'pw');

      s = await AppState.load(prefs: prefs, secrets: store);
      final back = s.machineById(m.id)!;
      expect(back.capabilities[ProtocolKind.vnc]!.enabled, isTrue);
      expect((await s.secretsFor(m.id))['vnc.password'], 'pw');
    });
  });

  group('vault', () {
    test('lock blocks secretsFor until unlocked', () async {
      final s = await _state();
      final m = await s.addMachine(name: 'box', host: 'h');
      await s.setSecret(m.id, 'ssh.password', 'pw');
      await s.setMachineLock(m.id, 'vault-pw');

      s.lockMachine(m.id);
      expect(s.isUnlocked(m.id), isFalse);
      expect(s.secretsFor(m.id), throwsA(isA<VaultLockedException>()));

      expect(await s.unlockMachine(m.id, 'wrong'), isFalse);
      expect(await s.unlockMachine(m.id, 'vault-pw'), isTrue);
      expect(s.isUnlocked(m.id), isTrue);
      expect((await s.secretsFor(m.id))['ssh.password'], 'pw');
    });

    test('secrets persist encrypted at rest', () async {
      final store = MemorySecretStore();
      final s = await _state(store: store);
      final m = await s.addMachine(name: 'box', host: 'h');
      await s.setSecret(m.id, 'ssh.password', 'hunter2');
      await s.setMachineLock(m.id, 'vault-pw');
      final blob = await store.read('m:${m.id}:secrets');
      expect(blob, isNot(contains('hunter2')));

      // edits while unlocked re-wrap under the cached key
      await s.setSecret(m.id, 'ssh.password', 'newpw');
      s.lockMachine(m.id);
      await s.unlockMachine(m.id, 'vault-pw');
      expect((await s.secretsFor(m.id))['ssh.password'], 'newpw');
    });

    test('removeMachineLock verifies password', () async {
      final s = await _state();
      final m = await s.addMachine(name: 'box', host: 'h');
      await s.setSecret(m.id, 'ssh.password', 'pw');
      await s.setMachineLock(m.id, 'vault-pw');
      s.lockMachine(m.id);

      expect(await s.removeMachineLock(m.id, 'bad'), isFalse);
      expect(s.machineById(m.id)!.locked, isTrue);
      expect(await s.removeMachineLock(m.id, 'vault-pw'), isTrue);
      expect(s.machineById(m.id)!.locked, isFalse);
      expect((await s.secretsFor(m.id))['ssh.password'], 'pw');
    });

    test('locked machine survives reload', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final store = MemorySecretStore();
      var s = await AppState.load(prefs: prefs, secrets: store);
      final m = await s.addMachine(name: 'box', host: 'h');
      await s.setSecret(m.id, 'ssh.password', 'pw');
      await s.setMachineLock(m.id, 'vault-pw');
      s.lockMachine(m.id);

      s = await AppState.load(prefs: prefs, secrets: store);
      expect(s.machineById(m.id)!.locked, isTrue);
      expect(s.secretsFor(m.id), throwsA(isA<VaultLockedException>()));
      expect(await s.unlockMachine(m.id, 'vault-pw'), isTrue);
      expect((await s.secretsFor(m.id))['ssh.password'], 'pw');
    });
  });

  group('ssh keys', () {
    test('generate stores pem, remove detaches from machines', () async {
      final s = await _state();
      final meta = await s.generateKey(SshKeyType.ed25519, 'mine');
      expect(s.keys, hasLength(1));
      expect(await s.privateKeyPem(meta.id), contains('OPENSSH PRIVATE KEY'));

      final m = await s.addMachine(name: 'b', host: 'h');
      final cfg = m.configFor(ProtocolKind.ssh) as SshConfig
        ..auth = SshAuth.publicKey
        ..keyId = meta.id;
      cfg.enabled = true;
      await s.updateMachine(m);

      await s.setKeyPassphrase(meta.id, 'pp');
      expect(await s.keyPassphrase(meta.id), 'pp');

      await s.removeKey(meta.id);
      expect(s.keys, isEmpty);
      expect(await s.privateKeyPem(meta.id), isNull);
      expect(await s.keyPassphrase(meta.id), isNull);
      final back = s.machineById(m.id)!.configFor(ProtocolKind.ssh) as SshConfig;
      expect(back.keyId, isNull);
      expect(back.auth, SshAuth.password);
    });

    test('import validates pem', () async {
      final s = await _state();
      final meta = await s.generateKey(SshKeyType.ed25519, 'orig');
      final pem = await s.privateKeyPem(meta.id);
      final imported = await s.importKey(pem!, name: 'copy');
      expect(imported.fingerprint, meta.fingerprint);
      expect(imported.name, 'copy');
      expect(s.importKey('not a pem'), throwsA(anything));
    });
  });

  group('sessions + known hosts', () {
    test('connect opens a vnc session and reuses it', () async {
      final s = await _state();
      // point the vnc driver at a scripted server
      s.registry.drivers[ProtocolKind.vnc] =
          VncDriver(connector: (h, p) async {
        final server = FakeRfbServer();
        Future.microtask(server.banner);
        return server;
      });

      final m = await s.addMachine(name: 'box', host: 'h');
      (m.configFor(ProtocolKind.vnc) as VncConfig).enabled = true;
      await s.updateMachine(m);

      final session = await s.connect(m, ProtocolKind.vnc);
      expect(s.sessionFor(m.id, ProtocolKind.vnc), same(session));
      final again = await s.connect(m, ProtocolKind.vnc);
      expect(again, same(session));

      await s.disconnect('vnc:${m.id}');
      expect(s.sessionFor(m.id, ProtocolKind.vnc), isNull);
      await s.disconnectAll();
    });

    test('connect replaces a failed session instead of reusing it',
        () async {
      final s = await _state();
      s.registry.drivers[ProtocolKind.vnc] =
          VncDriver(connector: (h, p) async {
        final server = FakeRfbServer();
        Future.microtask(server.banner);
        return server;
      });
      final m = await s.addMachine(name: 'box', host: 'h');
      (m.configFor(ProtocolKind.vnc) as VncConfig).enabled = true;
      await s.updateMachine(m);

      final session = await s.connect(m, ProtocolKind.vnc);
      await pumpEventQueue();
      session.emit(SessionPhase.failed, 'boom');
      final again = await s.connect(m, ProtocolKind.vnc);
      expect(again, isNot(same(session)));
      expect(s.sessionFor(m.id, ProtocolKind.vnc), same(again));
      await s.disconnectAll();
    });

    test('planned protocol throws', () async {
      final s = await _state();
      final m = await s.addMachine(name: 'box', host: 'h');
      (m.configFor(ProtocolKind.rdp)).enabled = true;
      await s.updateMachine(m);
      expect(s.connect(m, ProtocolKind.rdp), throwsA(isA<UnsupportedError>()));
    });

    test('host key TOFU pins then rejects changes', () async {
      final s = await _state();
      expect(s.knownHosts, isEmpty);
      expect(s.verifyHostKey('h1', 'ssh-ed25519', 'SHA256:fp1'), isTrue);
      expect(s.verifyHostKey('h1', 'ssh-ed25519', 'SHA256:fp1'), isTrue);
      expect(s.verifyHostKey('h1', 'ssh-ed25519', 'SHA256:CHANGED'), isFalse);
      expect(s.knownHosts['h1'], 'ssh-ed25519 SHA256:fp1');
      await s.forgetHostKey('h1');
      expect(s.knownHosts, isEmpty);
      expect(s.registry.driverFor(ProtocolKind.ssh).kind, ProtocolKind.ssh);
      expect(s.registry.driverFor(ProtocolKind.rdp).isImplemented, isFalse);
    });
  });

  group('navigation state', () {
    test('navIndex and selection notify', () async {
      final s = await _state();
      var notified = 0;
      s.addListener(() => notified++);
      s.navIndex = 1;
      s.selectedMachineId = 'x';
      s.navIndex = 1; // no-op, no notify
      expect(s.navIndex, 1);
      expect(s.selectedMachineId, 'x');
      expect(notified, 2);
    });
  });
}
