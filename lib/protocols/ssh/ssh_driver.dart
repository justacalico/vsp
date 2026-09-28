import 'dart:async';
import 'dart:typed_data';

import 'package:dartssh2/dartssh2.dart';

import '../../models/capability.dart';
import '../../models/machine.dart';
import '../../models/protocol_kind.dart';
import '../protocol_driver.dart';
import '../remote_session.dart';
import 'ssh_session.dart';

typedef SshSocketConnector = Future<SSHSocket> Function(String host, int port);
typedef PrivateKeyLoader = Future<String?> Function(String keyId);

/// Decides whether a presented host key is acceptable. [fingerprint] is
/// OpenSSH-style (`SHA256:…`). Return true to continue.
typedef HostKeyVerifier = FutureOr<bool> Function(
    String host, String type, String fingerprint);

class SshDriver extends ProtocolDriver {
  SshDriver({
    SshSocketConnector? socketConnector,
    PrivateKeyLoader? privateKeyLoader,
    HostKeyVerifier? hostKeyVerifier,
  })  : _connector = socketConnector ?? SSHSocket.connect,
        _keyLoader = privateKeyLoader ?? ((_) async => null),
        _verifyHostKey = hostKeyVerifier ?? ((_, _, _) => true);

  final SshSocketConnector _connector;
  final PrivateKeyLoader _keyLoader;
  final HostKeyVerifier _verifyHostKey;

  @override
  ProtocolKind get kind => ProtocolKind.ssh;

  @override
  Future<RemoteSession> connect(
      Machine machine, Map<String, String> secrets) async {
    final config = machine.configFor(ProtocolKind.ssh) as SshConfig;
    if (config.username.isEmpty) {
      throw const SshConfigException('SSH needs a username');
    }

    final List<SSHKeyPair> identities;
    if (config.auth == SshAuth.publicKey) {
      if (config.keyId == null) {
        throw const SshConfigException('No key selected for this machine');
      }
      final pem = await _keyLoader(config.keyId!);
      if (pem == null) {
        throw const SshConfigException('Stored key is missing');
      }
      identities =
          SSHKeyPair.fromPem(pem, secrets['ssh.keyPassphrase']);
      if (identities.isEmpty) {
        throw const SshConfigException('Could not parse stored key');
      }
    } else {
      identities = [];
    }

    final socket = await _connector(machine.host, config.port);
    final client = SSHClient(
      socket,
      username: config.username,
      identities: identities.isEmpty ? null : identities,
      onPasswordRequest: config.auth == SshAuth.password
          ? () => secrets['ssh.password'] ?? ''
          : null,
      onVerifyHostKey: (type, Uint8List fingerprint) =>
          _verifyHostKey(machine.host, type, String.fromCharCodes(fingerprint)),
    );

    final session = SshSession(machine, client);
    unawaited(client.authenticated.then((_) {
      session.emit(SessionPhase.connected);
    }).catchError((Object e) {
      session.emit(SessionPhase.failed, e.toString());
    }));
    return session;
  }
}

class SshConfigException implements Exception {
  const SshConfigException(this.message);

  final String message;

  @override
  String toString() => message;
}
