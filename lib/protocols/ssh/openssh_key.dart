import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' show sha256;

import '../../models/ssh_key.dart';

/// Codec for the `openssh-key-v1` private key format (ciphername "none"
/// only — we store passphrases separately in the vault rather than bake
/// them into the PEM, so decrypt-at-rest stays under our control).
class OpenSshKey {
  OpenSshKey._();

  static const _magic = 'openssh-key-v1\x00';
  static const _blockSize = 8;

  // ---- binary helpers -------------------------------------------------

  static void _wString(BytesBuilder b, List<int> data) {
    b.add([
      (data.length >> 24) & 0xFF,
      (data.length >> 16) & 0xFF,
      (data.length >> 8) & 0xFF,
      data.length & 0xFF,
    ]);
    b.add(data);
  }

  static void _wMpint(BytesBuilder b, BigInt v) {
    var bytes = _bigIntBytes(v);
    if (bytes.isEmpty) bytes = Uint8List(1);
    if (bytes[0] & 0x80 != 0) {
      bytes = Uint8List.fromList([0, ...bytes]);
    }
    _wString(b, bytes);
  }

  static Uint8List _bigIntBytes(BigInt v) {
    if (v == BigInt.zero) return Uint8List(0);
    final out = <int>[];
    var x = v;
    while (x > BigInt.zero) {
      out.insert(0, (x & BigInt.from(0xFF)).toInt());
      x = x >> 8;
    }
    return Uint8List.fromList(out);
  }

  /// Full `authorized_keys`-format public line.
  static String publicKeyLine(
          String algorithm, Uint8List blob, String comment) =>
      '$algorithm ${base64Encode(blob)}${comment.isEmpty ? '' : ' $comment'}';

  static String _pemWrap(Uint8List der) {
    final b64 = base64Encode(der);
    final lines = <String>[];
    for (var i = 0; i < b64.length; i += 70) {
      lines.add(b64.substring(i, i + 70 > b64.length ? b64.length : i + 70));
    }
    return '-----BEGIN OPENSSH PRIVATE KEY-----\n'
        '${lines.join('\n')}\n'
        '-----END OPENSSH PRIVATE KEY-----\n';
  }

  static Uint8List _pemUnwrap(String pem) {
    final body = pem
        .split('\n')
        .where((l) => !l.startsWith('-----') && l.trim().isNotEmpty)
        .join();
    return base64Decode(body);
  }

  static String fingerprint(Uint8List publicBlob) {
    final digest = sha256.convert(publicBlob).bytes;
    return 'SHA256:${base64Encode(digest).replaceAll('=', '')}';
  }

  // ---- public blobs ---------------------------------------------------

  static Uint8List ed25519PublicBlob(Uint8List pub32) {
    final b = BytesBuilder();
    _wString(b, utf8.encode('ssh-ed25519'));
    _wString(b, pub32);
    return b.toBytes();
  }

  static Uint8List rsaPublicBlob(BigInt n, BigInt e) {
    final b = BytesBuilder();
    _wString(b, utf8.encode('ssh-rsa'));
    _wMpint(b, e);
    _wMpint(b, n);
    return b.toBytes();
  }

  // ---- private key encode ---------------------------------------------

  static Uint8List _privateSection(
    String algorithm,
    Uint8List publicBlob,
    List<int> Function(BytesBuilder) writeFields,
    String comment,
  ) {
    final check = Random.secure().nextInt(0xFFFFFFFF);
    final fields = BytesBuilder();
    writeFields(fields);
    final b = BytesBuilder();
    b.add([(check >> 24) & 0xFF, (check >> 16) & 0xFF, (check >> 8) & 0xFF, check & 0xFF]);
    b.add([(check >> 24) & 0xFF, (check >> 16) & 0xFF, (check >> 8) & 0xFF, check & 0xFF]);
    _wString(b, utf8.encode(algorithm));
    b.add(fields.toBytes());
    _wString(b, utf8.encode(comment));
    var pad = 1;
    while (b.length % _blockSize != 0) {
      b.add([pad++]);
    }
    return b.toBytes();
  }

  static Uint8List _container(Uint8List publicBlob, Uint8List privateSection) {
    final b = BytesBuilder();
    b.add(ascii.encode(_magic));
    _wString(b, ascii.encode('none'));
    _wString(b, ascii.encode('none'));
    _wString(b, const []);
    b.add([0, 0, 0, 1]);
    _wString(b, publicBlob);
    _wString(b, privateSection);
    return b.toBytes();
  }

  /// Build the PEM for an Ed25519 keypair. [seed] is the 32-byte private
  /// seed, [pub] the 32-byte public key.
  static String encodeEd25519(Uint8List seed, Uint8List pub, String comment) {
    final blob = ed25519PublicBlob(pub);
    final priv = _privateSection('ssh-ed25519', blob, (f) {
      _wString(f, pub);
      _wString(f, Uint8List.fromList([...seed, ...pub]));
      return [];
    }, comment);
    return _pemWrap(_container(blob, priv));
  }

  /// Build the PEM for an RSA keypair.
  static String encodeRsa(
    BigInt n,
    BigInt e,
    BigInt d,
    BigInt p,
    BigInt q,
    String comment,
  ) {
    final blob = rsaPublicBlob(n, e);
    final iqmp = q.modInverse(p);
    final priv = _privateSection('ssh-rsa', blob, (f) {
      _wMpint(f, n);
      _wMpint(f, e);
      _wMpint(f, d);
      _wMpint(f, iqmp);
      _wMpint(f, p);
      _wMpint(f, q);
      return [];
    }, comment);
    return _pemWrap(_container(blob, priv));
  }

  // ---- private key decode (for import) --------------------------------

  static int _rU32(Uint8List d, List<int> pos) {
    final v = (d[pos[0]] << 24) | (d[pos[0] + 1] << 16) | (d[pos[0] + 2] << 8) | d[pos[0] + 3];
    pos[0] += 4;
    return v;
  }

  static Uint8List _rString(Uint8List d, List<int> pos) {
    final len = _rU32(d, pos);
    if (pos[0] + len > d.length) {
      throw const FormatException('Truncated key blob');
    }
    final out = d.sublist(pos[0], pos[0] + len);
    pos[0] += len;
    return out;
  }

  /// Parse an unencrypted `OPENSSH PRIVATE KEY` PEM. Returns the key
  /// metadata — the original PEM text is what callers should persist.
  /// Throws [FormatException] for encrypted or malformed keys.
  static SshKeyMeta parsePrivateKey(String pem, {String? id, String? name}) {
    if (!pem.contains('BEGIN OPENSSH PRIVATE KEY')) {
      throw const FormatException('Only unencrypted OpenSSH-format keys are supported');
    }
    final d = _pemUnwrap(pem);
    final magic = ascii.encode(_magic);
    if (d.length < magic.length + 12) {
      throw const FormatException('Not an OpenSSH key');
    }
    for (var i = 0; i < magic.length; i++) {
      if (d[i] != magic[i]) throw const FormatException('Not an OpenSSH key');
    }
    final pos = [magic.length];
    final cipher = utf8.decode(_rString(d, pos));
    if (cipher != 'none') {
      throw const FormatException('Passphrase-encrypted keys cannot be imported; decrypt it first');
    }
    _rString(d, pos); // kdf name
    _rString(d, pos); // kdf options
    final nkeys = _rU32(d, pos);
    if (nkeys != 1) throw const FormatException('Multi-key containers unsupported');
    final publicBlob = _rString(d, pos);
    final priv = _rString(d, pos);

    final ppos = [0];
    final check1 = _rU32(priv, ppos);
    final check2 = _rU32(priv, ppos);
    if (check1 != check2) throw const FormatException('Corrupt key (checkint mismatch)');
    final type = utf8.decode(_rString(priv, ppos));
    final keyType = switch (type) {
      'ssh-ed25519' => SshKeyType.ed25519,
      'ssh-rsa' => SshKeyType.rsa,
      _ => throw FormatException('Unsupported key type $type'),
    };
    // Skip the private fields; only the comment is needed.
    switch (keyType) {
      case SshKeyType.ed25519:
        _rString(priv, ppos); // pub
        _rString(priv, ppos); // priv
      case SshKeyType.rsa:
        for (var i = 0; i < 6; i++) {
          _rString(priv, ppos); // n, e, d, iqmp, p, q
        }
    }
    final comment = utf8.decode(_rString(priv, ppos), allowMalformed: true);

    return SshKeyMeta(
      id: id ?? '',
      name: name ?? (comment.isEmpty ? type : comment),
      type: keyType,
      publicKey: publicKeyLine(type, publicBlob, comment),
      fingerprint: fingerprint(publicBlob),
    );
  }
}
