import 'package:dartssh2/dartssh2.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vsp/models/ssh_key.dart';
import 'package:vsp/protocols/ssh/openssh_key.dart';
import 'package:vsp/protocols/ssh/ssh_keygen.dart';

void main() {
  group('SshKeyGen', () {
    test('ed25519 generates a parseable OpenSSH key', () async {
      final g = await SshKeyGen.ed25519('id1', 'laptop');
      expect(g.meta.type, SshKeyType.ed25519);
      expect(g.meta.publicKey, startsWith('ssh-ed25519 '));
      expect(g.meta.fingerprint, startsWith('SHA256:'));
      expect(g.privatePem, contains('BEGIN OPENSSH PRIVATE KEY'));
      // dartssh2 must be able to use what we generate.
      final pairs = SSHKeyPair.fromPem(g.privatePem);
      expect(pairs, isNotEmpty);
    });

    test('rsa generates a parseable OpenSSH key', () async {
      final g = await SshKeyGen.rsa('id2', 'deploy', bits: 2048);
      expect(g.meta.type, SshKeyType.rsa);
      expect(g.meta.publicKey, startsWith('ssh-rsa '));
      final pairs = SSHKeyPair.fromPem(g.privatePem);
      expect(pairs, isNotEmpty);
    }, timeout: const Timeout(Duration(seconds: 120)));
  });

  group('OpenSshKey.parsePrivateKey', () {
    test('roundtrips a generated ed25519 key', () async {
      final g = await SshKeyGen.ed25519('id', 'mine');
      final meta = OpenSshKey.parsePrivateKey(g.privatePem);
      expect(meta.type, SshKeyType.ed25519);
      expect(meta.fingerprint, g.meta.fingerprint);
      expect(meta.publicKey, g.meta.publicKey);
    });

    test('roundtrips a generated rsa key', () async {
      final g = await SshKeyGen.rsa('id', 'r', bits: 2048);
      final meta = OpenSshKey.parsePrivateKey(g.privatePem);
      expect(meta.type, SshKeyType.rsa);
      expect(meta.fingerprint, g.meta.fingerprint);
    }, timeout: const Timeout(Duration(seconds: 120)));

    test('rejects non-OpenSSH PEM', () {
      expect(
        () => OpenSshKey.parsePrivateKey(
            '-----BEGIN RSA PRIVATE KEY-----\nAAAA\n-----END RSA PRIVATE KEY-----'),
        throwsA(isA<FormatException>()),
      );
    });

    test('rejects garbage', () {
      expect(() => OpenSshKey.parsePrivateKey(
          '-----BEGIN OPENSSH PRIVATE KEY-----\nAAAA\n-----END OPENSSH PRIVATE KEY-----'),
          throwsA(anything));
    });
  });
}
