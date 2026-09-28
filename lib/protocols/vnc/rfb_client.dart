import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:typed_data';

import 'des.dart';
import 'rfb_channel.dart';

export 'rfb_channel.dart' show SocketConnector;

class RfbException implements Exception {
  const RfbException(this.message);

  final String message;

  @override
  String toString() => 'RfbException: $message';
}

enum RfbState { connecting, connected, failed, closed }

/// One decoded framebuffer update, emitted after it has been applied to
/// [RfbClient.pixels]. The UI repaints from the raw RGBX buffer.
class RfbFrame {
  const RfbFrame(this.width, this.height);

  final int width;
  final int height;
}

class RfbEvent {
  const RfbEvent(this.state, [this.message]);

  final RfbState state;
  final String? message;
}

/// A minimal RFB 3.8 client.
///
/// Supports security types None (1) and VNC auth (2), framebuffer
/// encodings Raw (0) and CopyRect (2), plus the DesktopSize (-223)
/// pseudo-encoding so a server-side resize reallocates the buffer.
/// The client requests pixels as 32-bit RGBX big-endian, which lands in
/// [pixels] ready for `ui.decodeImageFromPixels` with rgbx8888.
class RfbClient {
  RfbClient({
    required this.host,
    this.port = 5900,
    this.password,
    this.shared = true,
    SocketConnector? connector,
  }) : _connector = connector ?? defaultConnector;

  final String host;
  final int port;
  final String? password;
  final bool shared;
  final SocketConnector _connector;

  RfbChannel? _socket;
  StreamSubscription<Uint8List>? _sub;

  int width = 0;
  int height = 0;
  String serverName = '';
  Uint8List pixels = Uint8List(0);

  RfbState state = RfbState.connecting;

  final _events = StreamController<RfbEvent>.broadcast();
  final _frames = StreamController<RfbFrame>.broadcast();

  Stream<RfbEvent> get events => _events.stream;
  Stream<RfbFrame> get frames => _frames.stream;

  // Incoming byte buffer.
  final Queue<int> _in = Queue<int>();
  Completer<void>? _waiter;
  Object? _fatal;
  bool _closing = false;

  void _emit(RfbState s, [String? message]) {
    state = s;
    if (!_events.isClosed) _events.add(RfbEvent(s, message));
  }

  Future<void> _buffered(int n) {
    if (_in.length >= n) return Future.value();
    if (_fatal != null) return Future.error(_fatal!);
    _waiter ??= Completer<void>();
    return _waiter!.future;
  }

  void _onData(Uint8List chunk) {
    _in.addAll(chunk);
    if (_waiter != null && !_waiter!.isCompleted) {
      _waiter!.complete();
      _waiter = null;
    }
  }

  void _onError(Object error) {
    _fatal = error;
    if (_waiter != null && !_waiter!.isCompleted) {
      _waiter!.completeError(error);
      _waiter = null;
    }
    _fail(error.toString());
  }

  void _onDone() {
    if (!_closing && state != RfbState.failed) {
      _fatal = const RfbException('Connection closed by server');
      if (_waiter != null && !_waiter!.isCompleted) {
        _waiter!.completeError(_fatal!);
        _waiter = null;
      }
      _emit(RfbState.closed);
    }
  }

  Future<Uint8List> _read(int n) async {
    await _buffered(n);
    if (_in.length < n) throw _fatal ?? const RfbException('short read');
    final out = Uint8List(n);
    for (var i = 0; i < n; i++) {
      out[i] = _in.removeFirst();
    }
    return out;
  }

  Future<int> _u8() async => (await _read(1))[0];

  Future<int> _u16() async {
    final b = await _read(2);
    return (b[0] << 8) | b[1];
  }

  Future<int> _u32() async {
    final b = await _read(4);
    return (b[0] << 24) | (b[1] << 16) | (b[2] << 8) | b[3];
  }

  void _send(List<int> bytes) => _socket?.add(bytes);

  Future<void> connect() async {
    try {
      _socket = await _connector(host, port);
    } catch (e) {
      _fail('Could not reach $host:$port');
      rethrow;
    }
    _sub = _socket!.stream.listen(_onData,
        onError: _onError, onDone: _onDone, cancelOnError: false);

    try {
      await _handshake();
      _emit(RfbState.connected, serverName);
      unawaited(_messageLoop());
    } catch (e) {
      _fail(e is RfbException ? e.message : e.toString());
      rethrow;
    }
  }

  Future<void> _handshake() async {
    final banner = await _read(12);
    final version = ascii.decode(banner, allowInvalid: true);
    if (!version.startsWith('RFB ')) {
      throw const RfbException('Not an RFB server');
    }
    _send(ascii.encode('RFB 003.008\n'));

    // Security types.
    final count = await _u8();
    if (count == 0) {
      final len = await _u32();
      final reason = utf8.decode(await _read(len), allowMalformed: true);
      throw RfbException('Server refused connection: $reason');
    }
    final types = (await _read(count)).toSet();

    if (password != null && password!.isNotEmpty && types.contains(2)) {
      _send([2]);
      final challenge = await _read(16);
      _send(Des.encryptChallenge(password!, challenge));
    } else if (types.contains(1)) {
      _send([1]);
    } else {
      throw RfbException(
          'No supported security type (server offered: ${types.join(', ')})');
    }

    final result = await _u32();
    if (result == 1) {
      // 3.8 sends a failure reason string.
      try {
        final len = await _u32().timeout(const Duration(seconds: 3));
        final reason = utf8.decode(await _read(len), allowMalformed: true);
        throw RfbException(reason.isEmpty ? 'Authentication failed' : reason);
      } on TimeoutException {
        throw const RfbException('Authentication failed');
      }
    } else if (result != 0) {
      throw const RfbException('Too many authentication attempts');
    }

    // ClientInit / ServerInit.
    _send([shared ? 1 : 0]);
    width = await _u16();
    height = await _u16();
    await _read(16); // server pixel format — we override below
    final nameLen = await _u32();
    serverName = utf8.decode(await _read(nameLen), allowMalformed: true);
    pixels = Uint8List(width * height * 4);

    // Ask for 32bpp on the wire: big-endian true-color with R in the
    // top byte gives us R,G,B,pad byte order — one alpha fixup pass
    // away from valid rgba8888 for decodeImageFromPixels.
    _send([
      0, 0, 0, 0,
      32, 24, 1, 1, // bpp, depth, bigEndian, trueColor
      0, 255, 0, 255, 0, 255, // rMax, gMax, bMax
      24, 16, 8, // rShift, gShift, bShift
      0, 0, 0,
    ]);

    // Raw, CopyRect, DesktopSize.
    _send([2, 0, 0, 3, 0, 0, 0, 0, 0, 0, 0, 2, 0xFF, 0xFF, 0xFF, 0x21]);

    await requestUpdate(incremental: false);
  }

  Future<void> requestUpdate({bool incremental = true}) async {
    _send([3, incremental ? 1 : 0, 0, 0, 0, 0,
      (width >> 8) & 0xFF, width & 0xFF,
      (height >> 8) & 0xFF, height & 0xFF]);
  }

  void sendPointer(int x, int y, int buttonMask) {
    _send([5, buttonMask & 0xFF, (x >> 8) & 0xFF, x & 0xFF,
      (y >> 8) & 0xFF, y & 0xFF]);
  }

  void sendKey(int keysym, {required bool down}) {
    _send([4, down ? 1 : 0, 0, 0, (keysym >> 24) & 0xFF, (keysym >> 16) & 0xFF,
      (keysym >> 8) & 0xFF, keysym & 0xFF]);
  }

  void sendCutText(String text) {
    final bytes = latin1.encode(text);
    _send([6, 0, 0, 0, (bytes.length >> 24) & 0xFF, (bytes.length >> 16) & 0xFF,
      (bytes.length >> 8) & 0xFF, bytes.length & 0xFF, ...bytes]);
  }

  void _applyRaw(int x, int y, int w, int h, Uint8List data) {
    final stride = width * 4;
    final rowBytes = w * 4;
    for (var row = 0; row < h; row++) {
      final dst = ((y + row) * stride) + x * 4;
      final src = row * rowBytes;
      if (dst + rowBytes <= pixels.length && src + rowBytes <= data.length) {
        pixels.setRange(dst, dst + rowBytes, data, src);
        // The wire carries R,G,B,pad — set alpha opaque so rgba8888
        // decoding renders the frame instead of transparent pixels.
        for (var i = dst + 3; i < dst + rowBytes; i += 4) {
          pixels[i] = 0xFF;
        }
      }
    }
  }

  void _applyCopyRect(int x, int y, int w, int h, int sx, int sy) {
    final stride = width * 4;
    final rowBytes = w * 4;
    final tmp = Uint8List(rowBytes);
    for (var row = 0; row < h; row++) {
      final src = ((sy + row) * stride) + sx * 4;
      final dst = ((y + row) * stride) + x * 4;
      if (src + rowBytes <= pixels.length && dst + rowBytes <= pixels.length) {
        tmp.setRange(0, rowBytes, pixels, src);
        pixels.setRange(dst, dst + rowBytes, tmp);
      }
    }
  }

  Future<void> _messageLoop() async {
    try {
      while (state == RfbState.connected) {
        final type = await _u8();
        switch (type) {
          case 0: // FramebufferUpdate
            await _u8(); // padding
            final nrects = await _u16();
            for (var i = 0; i < nrects; i++) {
              final x = await _u16();
              final y = await _u16();
              final w = await _u16();
              final h = await _u16();
              final enc = await _u32();
              final encoding = enc >= 0x80000000 ? enc - 0x100000000 : enc;
              switch (encoding) {
                case 0:
                  _applyRaw(x, y, w, h, await _read(w * h * 4));
                case 2:
                  final sx = await _u16();
                  final sy = await _u16();
                  _applyCopyRect(x, y, w, h, sx, sy);
                case -223: // DesktopSize
                  width = w;
                  height = h;
                  pixels = Uint8List(w * h * 4);
                  await requestUpdate(incremental: false);
                default:
                  throw RfbException('Unsupported encoding $encoding');
              }
            }
            if (!_frames.isClosed) _frames.add(RfbFrame(width, height));
            await requestUpdate(incremental: true);
          case 1: // SetColourMapEntries
            await _u8();
            await _u16();
            final n = await _u16();
            await _read(n * 6);
          case 2: // Bell
            break;
          case 3: // ServerCutText
            await _read(3);
            final len = await _u32();
            await _read(len);
          default:
            throw RfbException('Unknown server message $type');
        }
      }
    } catch (e) {
      if (!_closing) {
        _fail(e is RfbException ? e.message : e.toString());
      }
    }
  }

  void _fail(String message) {
    if (state != RfbState.failed) _emit(RfbState.failed, message);
  }

  Future<void> close() async {
    _closing = true;
    if (state == RfbState.connected || state == RfbState.connecting) {
      _emit(RfbState.closed);
    }
    // Socket first: its done event ends the subscription cleanly.
    // Cancelling before closing can strand a scripted channel waiting
    // to deliver done to a dead listener.
    await _socket?.close();
    await _sub?.cancel();
    if (!_frames.isClosed) await _frames.close();
    if (!_events.isClosed) await _events.close();
  }
}
