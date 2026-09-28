import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:vsp/protocols/vnc/des.dart';

void main() {
  group('Des', () {
    test('known vector: encryptBlock', () {
      // Classic DES test vector.
      final ct = Des.encryptBlock(0x0123456789ABCDEF, 0x133457799BBCDFF1);
      expect(ct, 0x85E813540F0AB405);
    });

    test('bytes<->int roundtrip', () {
      final b = Uint8List.fromList([1, 2, 3, 4, 5, 6, 7, 8]);
      expect(Des.bytesToInt(b), 0x0102030405060708);
      expect(Des.intToBytes(0x0102030405060708), b);
    });

    test('vncKey truncates and bit-reverses password', () {
      // 'a' = 0x61 -> reversed 0x86
      final k = Des.vncKey('a');
      expect(Des.intToBytes(k)[0], 0x86);
      // longer than 8 chars is truncated to 8 bytes
      final k8 = Des.vncKey('abcdefgh');
      final kLong = Des.vncKey('abcdefghijklmnopqrstuvwxyz');
      expect(k8, kLong);
      // empty password -> all-zero key
      expect(Des.vncKey(''), 0);
    });

    test('encryptChallenge produces deterministic 16 bytes', () {
      final challenge = Uint8List.fromList(List.generate(16, (i) => i));
      final a = Des.encryptChallenge('pw', challenge);
      final b = Des.encryptChallenge('pw', challenge);
      expect(a, b);
      expect(a.length, 16);
      final c = Des.encryptChallenge('other', challenge);
      expect(c, isNot(a));
    });
  });
}
