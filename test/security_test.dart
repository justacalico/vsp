import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:vsp/security/secure_store.dart';
import 'package:vsp/security/vault.dart';

void main() {
  group('Vault', () {
    test('wrap/unwrap roundtrip', () async {
      final salt = Vault.newSalt();
      final secrets = {'ssh.password': 'hunter2', 'vnc.password': 'p4ss'};
      final blob = await Vault.wrap(secrets, 'correct', salt);
      expect(blob, isNot(contains('hunter2')));
      final back = await Vault.unwrap(blob, 'correct', salt);
      expect(back, secrets);
    });

    test('wrong password throws VaultLockedException', () async {
      final salt = Vault.newSalt();
      final blob = await Vault.wrap({'a': 'b'}, 'right', salt);
      expect(Vault.unwrap(blob, 'wrong', salt),
          throwsA(isA<VaultLockedException>()));
    });

    test('corrupt blob throws', () async {
      final salt = Vault.newSalt();
      expect(Vault.unwrap('!!!notbase64!!!', 'x', salt),
          throwsA(isA<VaultLockedException>()));
      expect(Vault.unwrap(base64Encode(Uint8List(4)), 'x', salt),
          throwsA(isA<VaultLockedException>()));
      // valid length, garbage content
      expect(Vault.unwrap(base64Encode(Uint8List(64)), 'x', salt),
          throwsA(isA<VaultLockedException>()));
    });

    test('plain encode/decode', () {
      expect(Vault.decodePlain(Vault.encodePlain({'a': '1', 'b': '2'})),
          {'a': '1', 'b': '2'});
      expect(Vault.decodePlain('{}'), isEmpty);
      expect(Vault.decodePlain('[1,2]'), isEmpty);
    });

    test('newSalt is random and 16 bytes', () {
      final a = Vault.newSalt();
      final b = Vault.newSalt();
      expect(a.length, 16);
      expect(base64Encode(a), isNot(base64Encode(b)));
    });
  });

  group('MemorySecretStore', () {
    test('read/write/delete', () async {
      final s = MemorySecretStore();
      expect(await s.read('k'), isNull);
      await s.write('k', 'v');
      expect(await s.read('k'), 'v');
      await s.write('k', null);
      expect(await s.read('k'), isNull);
    });
  });
}
