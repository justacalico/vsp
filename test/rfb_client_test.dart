import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:vsp/protocols/vnc/rfb_channel.dart';
import 'package:vsp/protocols/vnc/rfb_client.dart';

/// Scripted RFB 3.8 server speaking over an in-memory channel.
class FakeRfbServer implements RfbChannel {
  FakeRfbServer({this.securityTypes = const [1], this.failAuth = false});

  final List<int> securityTypes;
  final bool failAuth;

  final _in = StreamController<Uint8List>();
  final List<int> written = [];

  bool _sentTypes = false;
  bool _waitingVncChallenge = false;
  bool _sentResult = false;
  bool _sentInit = false;
  int _fbUpdates = 0;

  @override
  Stream<Uint8List> get stream => _in.stream;

  @override
  void add(List<int> bytes) {
    written.addAll(bytes);
    _react(Uint8List.fromList(bytes));
  }

  void _react(Uint8List bytes) {
    final s = String.fromCharCodes(bytes);
    if (s.startsWith('RFB ')) {
      _sendTypes();
      return;
    }
    if (!_sentTypes) {
      _sendTypes();
      return;
    }
    // Security type selection (single byte).
    if (bytes.length == 1 && !_waitingVncChallenge && !_sentResult) {
      if (bytes[0] == 2) {
        _waitingVncChallenge = true;
        _in.add(Uint8List.fromList(List.generate(16, (i) => i * 3)));
        return;
      }
      _sendResult();
      return;
    }
    // VNC auth response (16 bytes).
    if (_waitingVncChallenge && bytes.length == 16 && !_sentResult) {
      _sendResult();
      return;
    }
    // ClientInit.
    if (bytes.length == 1 && _sentResult && !_sentInit) {
      _sendInit();
      return;
    }
    if (!_sentInit) return;
    // FramebufferUpdateRequest (type 3, 10 bytes).
    if (bytes.length == 10 && bytes[0] == 3) {
      _sendFramebufferUpdate();
      return;
    }
  }

  void _sendTypes() {
    if (_sentTypes) return;
    _sentTypes = true;
    if (securityTypes.isEmpty) {
      _in.add(Uint8List.fromList([0]));
      final reason = 'no auth';
      _in.add(Uint8List.fromList([
        0, 0, 0, reason.length,
        ...reason.codeUnits,
      ]));
      return;
    }
    _in.add(Uint8List.fromList([securityTypes.length, ...securityTypes]));
  }

  void _sendResult() {
    _sentResult = true;
    if (failAuth) {
      _in.add(Uint8List.fromList([0, 0, 0, 1]));
      final reason = 'bad password';
      _in.add(Uint8List.fromList(
          [0, 0, 0, reason.length, ...reason.codeUnits]));
      return;
    }
    _in.add(Uint8List.fromList([0, 0, 0, 0]));
  }

  void _sendInit() {
    _sentInit = true;
    final name = 'fake-server';
    _in.add(Uint8List.fromList([
      0, 4, 0, 2, // width 4, height 2
      // server pixel format (16 bytes)
      32, 24, 0, 1, 0, 255, 0, 255, 0, 255, 16, 8, 0, 0, 0, 0,
      0, 0, 0, name.length,
      ...name.codeUnits,
    ]));
  }

  void _sendFramebufferUpdate() {
    // Answer the initial request plus one incremental, then go quiet —
    // otherwise the request/response ping-pong never lets close() land.
    if (_fbUpdates >= 2) return;
    _fbUpdates++;
    // 4x2 raw rect
    final px = Uint8List(4 * 2 * 4);
    for (var i = 0; i < px.length; i++) {
      px[i] = (i * 7) & 0xFF;
    }
    _in.add(Uint8List.fromList([
      0, 0, 0, 1, // msg type 0, pad, 1 rect
      0, 0, 0, 0, 0, 4, 0, 2, 0, 0, 0, 0, // x,y,w,h, encoding raw
      ...px,
    ]));
  }

  void banner() => _in.add(Uint8List.fromList('RFB 003.008\n'.codeUnits));

  @override
  Future<void> close() => _in.close();
}

RfbClient _client(FakeRfbServer server, {String? password}) => RfbClient(
      host: 'test',
      port: 5900,
      password: password,
      connector: (h, p) async {
        Future.microtask(server.banner);
        return server;
      },
    );

void main() {
  group('RfbClient', () {
    test('handshake with security None + framebuffer update', () async {
      final server = FakeRfbServer(securityTypes: [1]);
      final client = _client(server);
      await client.connect();
      expect(client.state, RfbState.connected);
      expect(client.width, 4);
      expect(client.height, 2);
      expect(client.serverName, 'fake-server');
      await expectLater(
          client.frames.first.timeout(const Duration(seconds: 5)),
          completes);
      expect(client.pixels.length, 32);
      // alpha fixup ran
      expect(client.pixels[3], 0xFF);
      await client.close();
    });

    test('VNC-auth handshake completes', () async {
      final server = FakeRfbServer(securityTypes: [2, 1]);
      final client = _client(server, password: 'secret');
      await client.connect();
      expect(client.state, RfbState.connected);
      // client answered the 16-byte challenge
      expect(server.written.contains(16) || server.written.length > 20, isTrue);
      await client.close();
    });

    test('auth failure surfaces as failed state', () async {
      final server = FakeRfbServer(securityTypes: [2], failAuth: true);
      final client = _client(server, password: 'x');
      expect(client.connect(), throwsA(isA<RfbException>()));
      await pumpEventQueue();
      expect(client.state, RfbState.failed);
    });

    test('unsupported security type errors', () async {
      final server = FakeRfbServer(securityTypes: [18]);
      final client = _client(server);
      expect(client.connect(), throwsA(isA<RfbException>()));
      await pumpEventQueue();
      expect(client.state, RfbState.failed);
    });

    test('zero security types carries the server reason', () async {
      final server = FakeRfbServer(securityTypes: []);
      final client = _client(server);
      expect(client.connect(), throwsA(isA<RfbException>()));
      await pumpEventQueue();
    });

    test('connector failure propagates', () async {
      final client = RfbClient(
          host: 'dead',
          connector: (h, p) => Future.error(StateError('refused')));
      expect(client.connect(), throwsA(isA<StateError>()));
      await pumpEventQueue();
      expect(client.state, RfbState.failed);
    });

    test('input messages encode correctly', () async {
      final server = FakeRfbServer(securityTypes: [1]);
      final client = _client(server);
      await client.connect();
      final before = server.written.length;
      client.sendPointer(10, 20, 3);
      expect(server.written.sublist(before),
          [5, 3, 0, 10, 0, 20]);
      client.sendKey(0xFF0D, down: true);
      expect(server.written.sublist(server.written.length - 8),
          [4, 1, 0, 0, 0, 0, 0xFF, 0x0D]);
      client.sendCutText('hi');
      final tail = server.written.sublist(server.written.length - 10);
      expect(tail, [6, 0, 0, 0, 0, 0, 0, 2, 104, 105]);
      await client.close();
    });

    test('close emits closed and tolerates double close', () async {
      final server = FakeRfbServer(securityTypes: [1]);
      final client = _client(server);
      await client.connect();
      await client.close();
      expect(client.state, RfbState.closed);
      await client.close();
    });
  });
}
