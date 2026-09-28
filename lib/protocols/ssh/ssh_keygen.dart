import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:pointycastle/export.dart';

import '../../models/ssh_key.dart';
import 'openssh_key.dart';

/// A freshly generated keypair: metadata for the list UI plus the PEM
/// to stash in secure storage.
class GeneratedKey {
  const GeneratedKey({required this.meta, required this.privatePem});

  final SshKeyMeta meta;
  final String privatePem;
}

/// Generates OpenSSH-format keypairs. Pure Dart — no dependency on a
/// host `ssh-keygen` binary, so it works on Android and iOS too.
class SshKeyGen {
  SshKeyGen._();

  static Future<GeneratedKey> ed25519(String id, String name) async {
    final pair = await Ed25519().newKeyPair();
    final data = await pair.extract();
    final seed = Uint8List.fromList(data.bytes);
    final pub = Uint8List.fromList(data.publicKey.bytes);
    final pem = OpenSshKey.encodeEd25519(seed, pub, name);
    final blob = OpenSshKey.ed25519PublicBlob(pub);
    return GeneratedKey(
      meta: SshKeyMeta(
        id: id,
        name: name,
        type: SshKeyType.ed25519,
        publicKey: OpenSshKey.publicKeyLine('ssh-ed25519', blob, name),
        fingerprint: OpenSshKey.fingerprint(blob),
      ),
      privatePem: pem,
    );
  }

  static Future<GeneratedKey> rsa(String id, String name,
      {int bits = 3072}) async {
    final secureRandom = FortunaRandom()
      ..seed(KeyParameter(Uint8List.fromList(
          List.generate(32, (_) => Random.secure().nextInt(256)))));
    final gen = RSAKeyGenerator()
      ..init(ParametersWithRandom(
          RSAKeyGeneratorParameters(BigInt.from(65537), bits, 64),
          secureRandom));
    final pair = gen.generateKeyPair();
    final priv = pair.privateKey;
    final pub = pair.publicKey;
    final n = pub.modulus!;
    final e = pub.publicExponent!;
    final pem = OpenSshKey.encodeRsa(
        n, e, priv.privateExponent!, priv.p!, priv.q!, name);
    final blob = OpenSshKey.rsaPublicBlob(n, e);
    return GeneratedKey(
      meta: SshKeyMeta(
        id: id,
        name: name,
        type: SshKeyType.rsa,
        publicKey: OpenSshKey.publicKeyLine('ssh-rsa', blob, name),
        fingerprint: OpenSshKey.fingerprint(blob),
      ),
      privatePem: pem,
    );
  }
}
