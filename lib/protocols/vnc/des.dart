import 'dart:typed_data';

/// Single-DES block cipher, implemented directly so the VNC driver has
/// no dependency on pointycastle's registry API (which churns between
/// majors). VNC "password" auth DES-encrypts the server challenge with
/// a key built from bit-reversed password bytes.
class Des {
  Des._();

  static const _ip = [
    58, 50, 42, 34, 26, 18, 10, 2, 60, 52, 44, 36, 28, 20, 12, 4,
    62, 54, 46, 38, 30, 22, 14, 6, 64, 56, 48, 40, 32, 24, 16, 8,
    57, 49, 41, 33, 25, 17, 9, 1, 59, 51, 43, 35, 27, 19, 11, 3,
    61, 53, 45, 37, 29, 21, 13, 5, 63, 55, 47, 39, 31, 23, 15, 7,
  ];

  static const _fp = [
    40, 8, 48, 16, 56, 24, 64, 32, 39, 7, 47, 15, 55, 23, 63, 31,
    38, 6, 46, 14, 54, 22, 62, 30, 37, 5, 45, 13, 53, 21, 61, 29,
    36, 4, 44, 12, 52, 20, 60, 28, 35, 3, 43, 11, 51, 19, 59, 27,
    34, 2, 42, 10, 50, 18, 58, 26, 33, 1, 41, 9, 49, 17, 57, 25,
  ];

  static const _e = [
    32, 1, 2, 3, 4, 5, 4, 5, 6, 7, 8, 9,
    8, 9, 10, 11, 12, 13, 12, 13, 14, 15, 16, 17,
    16, 17, 18, 19, 20, 21, 20, 21, 22, 23, 24, 25,
    24, 25, 26, 27, 28, 29, 28, 29, 30, 31, 32, 1,
  ];

  static const _p = [
    16, 7, 20, 21, 29, 12, 28, 17, 1, 15, 23, 26,
    5, 18, 31, 10, 2, 8, 24, 14, 32, 27, 3, 9,
    19, 13, 30, 6, 22, 11, 4, 25,
  ];

  static const _s = [
    [
      14, 4, 13, 1, 2, 15, 11, 8, 3, 10, 6, 12, 5, 9, 0, 7,
      0, 15, 7, 4, 14, 2, 13, 1, 10, 6, 12, 11, 9, 5, 3, 8,
      4, 1, 14, 8, 13, 6, 2, 11, 15, 12, 9, 7, 3, 10, 5, 0,
      15, 12, 8, 2, 4, 9, 1, 7, 5, 11, 3, 14, 10, 0, 6, 13,
    ],
    [
      15, 1, 8, 14, 6, 11, 3, 4, 9, 7, 2, 13, 12, 0, 5, 10,
      3, 13, 4, 7, 15, 2, 8, 14, 12, 0, 1, 10, 6, 9, 11, 5,
      0, 14, 7, 11, 10, 4, 13, 1, 5, 8, 12, 6, 9, 3, 2, 15,
      13, 8, 10, 1, 3, 15, 4, 2, 11, 6, 7, 12, 0, 5, 14, 9,
    ],
    [
      10, 0, 9, 14, 6, 3, 15, 5, 1, 13, 12, 7, 11, 4, 2, 8,
      13, 7, 0, 9, 3, 4, 6, 10, 2, 8, 5, 14, 12, 11, 15, 1,
      13, 6, 4, 9, 8, 15, 3, 0, 11, 1, 2, 12, 5, 10, 14, 7,
      1, 10, 13, 0, 6, 9, 8, 7, 4, 15, 14, 3, 11, 5, 2, 12,
    ],
    [
      7, 13, 14, 3, 0, 6, 9, 10, 1, 2, 8, 5, 11, 12, 4, 15,
      13, 8, 11, 5, 6, 15, 0, 3, 4, 7, 2, 12, 1, 10, 14, 9,
      10, 6, 9, 0, 12, 11, 7, 13, 15, 1, 3, 14, 5, 2, 8, 4,
      3, 15, 0, 6, 10, 1, 13, 8, 9, 4, 5, 11, 12, 7, 2, 14,
    ],
    [
      2, 12, 4, 1, 7, 10, 11, 6, 8, 5, 3, 15, 13, 0, 14, 9,
      14, 11, 2, 12, 4, 7, 13, 1, 5, 0, 15, 10, 3, 9, 8, 6,
      4, 2, 1, 11, 10, 13, 7, 8, 15, 9, 12, 5, 6, 3, 0, 14,
      11, 8, 12, 7, 1, 14, 2, 13, 6, 15, 0, 9, 10, 4, 5, 3,
    ],
    [
      12, 1, 10, 15, 9, 2, 6, 8, 0, 13, 3, 4, 14, 7, 5, 11,
      10, 15, 4, 2, 7, 12, 9, 5, 6, 1, 13, 14, 0, 11, 3, 8,
      9, 14, 15, 5, 2, 8, 12, 3, 7, 0, 4, 10, 1, 13, 11, 6,
      4, 3, 2, 12, 9, 5, 15, 10, 11, 14, 1, 7, 6, 0, 8, 13,
    ],
    [
      4, 11, 2, 14, 15, 0, 8, 13, 3, 12, 9, 7, 5, 10, 6, 1,
      13, 0, 11, 7, 4, 9, 1, 10, 14, 3, 5, 12, 2, 15, 8, 6,
      1, 4, 11, 13, 12, 3, 7, 14, 10, 15, 6, 8, 0, 5, 9, 2,
      6, 11, 13, 8, 1, 4, 10, 7, 9, 5, 0, 15, 14, 2, 3, 12,
    ],
    [
      13, 2, 8, 4, 6, 15, 11, 1, 10, 9, 3, 14, 5, 0, 12, 7,
      1, 15, 13, 8, 10, 3, 7, 4, 12, 5, 6, 11, 0, 14, 9, 2,
      7, 11, 4, 1, 9, 12, 14, 2, 0, 6, 10, 13, 15, 3, 5, 8,
      2, 1, 14, 7, 4, 10, 8, 13, 15, 12, 9, 0, 3, 5, 6, 11,
    ],
  ];

  static const _pc1 = [
    57, 49, 41, 33, 25, 17, 9, 1, 58, 50, 42, 34, 26, 18,
    10, 2, 59, 51, 43, 35, 27, 19, 11, 3, 60, 52, 44, 36,
    63, 55, 47, 39, 31, 23, 15, 7, 62, 54, 46, 38, 30, 22,
    14, 6, 61, 53, 45, 37, 29, 21, 13, 5, 28, 20, 12, 4,
  ];

  static const _pc2 = [
    14, 17, 11, 24, 1, 5, 3, 28, 15, 6, 21, 10,
    23, 19, 12, 4, 26, 8, 16, 7, 27, 20, 13, 2,
    41, 52, 31, 37, 47, 55, 30, 40, 51, 45, 33, 48,
    44, 49, 39, 56, 34, 53, 46, 42, 50, 36, 29, 32,
  ];

  static const _rotations = [1, 1, 2, 2, 2, 2, 2, 2, 1, 2, 2, 2, 2, 2, 2, 1];

  static int _permute(int value, List<int> table, int srcBits) {
    var out = 0;
    for (final pos in table) {
      out = (out << 1) | ((value >> (srcBits - pos)) & 1);
    }
    return out;
  }

  static int _rotl28(int v, int n) => ((v << n) | (v >> (28 - n))) & 0x0FFFFFFF;

  static List<int> _subkeys(int key64) {
    final k56 = _permute(key64, _pc1, 64);
    var c = (k56 >> 28) & 0x0FFFFFFF;
    var d = k56 & 0x0FFFFFFF;
    final keys = <int>[];
    for (final r in _rotations) {
      c = _rotl28(c, r);
      d = _rotl28(d, r);
      keys.add(_permute((c << 28) | d, _pc2, 56));
    }
    return keys;
  }

  static int _round(int r32, int k48) {
    final expanded = _permute(r32, _e, 32) ^ k48;
    var sOut = 0;
    for (var i = 0; i < 8; i++) {
      final chunk = (expanded >> (42 - 6 * i)) & 0x3F;
      final row = ((chunk & 0x20) >> 4) | (chunk & 1);
      final col = (chunk >> 1) & 0x0F;
      sOut = (sOut << 4) | _s[i][row * 16 + col];
    }
    return _permute(sOut, _p, 32);
  }

  /// Encrypt a single 8-byte block.
  static int encryptBlock(int block, int key64) {
    var v = _permute(block, _ip, 64);
    var l = (v >> 32) & 0xFFFFFFFF;
    var r = v & 0xFFFFFFFF;
    for (final k in _subkeys(key64)) {
      final t = l ^ _round(r, k);
      l = r;
      r = t;
    }
    return _permute((r << 32) | l, _fp, 64);
  }

  static int bytesToInt(Uint8List b, [int offset = 0]) {
    var v = 0;
    for (var i = 0; i < 8; i++) {
      v = (v << 8) | b[offset + i];
    }
    return v;
  }

  static Uint8List intToBytes(int v) {
    final out = Uint8List(8);
    for (var i = 7; i >= 0; i--) {
      out[i] = v & 0xFF;
      v >>= 8;
    }
    return out;
  }

  /// VNC key quirk: password is truncated/padded to 8 bytes and each
  /// byte's bits are reversed before it becomes the DES key.
  static int vncKey(String password) {
    final src = Uint8List.fromList(password.codeUnits.take(8).toList());
    final keyBytes = Uint8List(8);
    for (var i = 0; i < src.length && i < 8; i++) {
      keyBytes[i] = _reverseBits(src[i]);
    }
    return bytesToInt(keyBytes);
  }

  static int _reverseBits(int b) {
    var v = 0;
    for (var i = 0; i < 8; i++) {
      v = (v << 1) | ((b >> i) & 1);
    }
    return v;
  }

  /// Encrypt a 16-byte VNC challenge with [password] (two ECB blocks).
  static Uint8List encryptChallenge(String password, Uint8List challenge) {
    assert(challenge.length == 16);
    final key = vncKey(password);
    final out = BytesBuilder()
      ..add(intToBytes(encryptBlock(bytesToInt(challenge, 0), key)))
      ..add(intToBytes(encryptBlock(bytesToInt(challenge, 8), key)));
    return out.toBytes();
  }
}
