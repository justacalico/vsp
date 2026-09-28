import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

/// Wrong-password (or corrupt blob) signal from [Vault.unwrap].
class VaultLockedException implements Exception {
  const VaultLockedException();

  @override
  String toString() => 'VaultLockedException';
}

/// Encrypts a machine's secret map behind a user password.
///
/// Format: secrets are JSON-encoded, then AES-GCM encrypted with a key
/// derived from the password via Argon2id. On disk a locked machine
/// stores base64(`nonce || ciphertext || mac`); the salt lives in the
/// machine metadata.
///
/// Unlocked machines store the same map as plain JSON inside secure
/// storage — the platform keystore already protects it at rest; locking
/// is about needing the password before connect.
class Vault {
  Vault._();

  static const _kdfMemoryKiB = 65536;
  static const _kdfParallelism = 2;
  static const _kdfIterations = 2;
  static const _nonceLen = 12;
  static const _saltLen = 16;
  static const _keyLen = 32;

  static final _aead = AesGcm.with256bits();
  static final _kdf = Argon2id(
    memory: _kdfMemoryKiB,
    parallelism: _kdfParallelism,
    iterations: _kdfIterations,
    hashLength: _keyLen,
  );

  static Uint8List newSalt() => Uint8List.fromList(
      List.generate(_saltLen, (_) => Random.secure().nextInt(256)));

  /// Derive the AES key for [password] + [salt]. Callers that keep the
  /// key can re-encrypt without asking the password again.
  static Future<SecretKey> deriveKey(String password, Uint8List salt) =>
      _kdf.deriveKeyFromPassword(password: password, nonce: salt);

  /// Serialize a secret map for an unlocked machine.
  static String encodePlain(Map<String, String> secrets) => jsonEncode(secrets);

  static Map<String, String> decodePlain(String blob) {
    final raw = jsonDecode(blob);
    if (raw is Map) {
      return raw.map((k, v) => MapEntry(k.toString(), v.toString()));
    }
    return {};
  }

  static Future<String> wrap(
      Map<String, String> secrets, String password, Uint8List salt) async {
    return wrapWithKey(secrets, await deriveKey(password, salt));
  }

  /// Encrypt under an already-derived key. Returns base64 of
  /// `nonce || ciphertext || mac`.
  static Future<String> wrapWithKey(
      Map<String, String> secrets, SecretKey key) async {
    final nonce = Uint8List.fromList(
        List.generate(_nonceLen, (_) => Random.secure().nextInt(256)));
    final box = await _aead.encrypt(
      utf8.encode(jsonEncode(secrets)),
      secretKey: key,
      nonce: nonce,
    );
    final out = BytesBuilder()
      ..add(nonce)
      ..add(box.cipherText)
      ..add(box.mac.bytes);
    return base64Encode(out.toBytes());
  }

  static Future<Map<String, String>> unwrap(
      String blob, String password, Uint8List salt) {
    return deriveKey(password, salt)
        .then((key) => unwrapWithKey(blob, key));
  }

  /// Decrypt a blob produced by [wrap]/[wrapWithKey] under an
  /// already-derived key. Throws [VaultLockedException] on wrong key or
  /// corrupt input.
  static Future<Map<String, String>> unwrapWithKey(
      String blob, SecretKey key) async {
    final Uint8List raw;
    try {
      raw = base64Decode(blob);
    } on FormatException {
      throw const VaultLockedException();
    }
    if (raw.length < _nonceLen + 16) throw const VaultLockedException();
    final box = SecretBox(
      raw.sublist(_nonceLen, raw.length - 16),
      nonce: raw.sublist(0, _nonceLen),
      mac: Mac(raw.sublist(raw.length - 16)),
    );
    try {
      final plain = await _aead.decrypt(box, secretKey: key);
      return decodePlain(utf8.decode(plain));
    } on SecretBoxAuthenticationError {
      throw const VaultLockedException();
    } on FormatException {
      throw const VaultLockedException();
    }
  }
}
