import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../protocols/vnc/keysyms.dart';
import '../protocols/vnc/vnc_session.dart';

/// Remote desktop surface. Renders the RFB framebuffer via
/// decodeImageFromPixels and forwards pointer/keyboard events unless
/// the machine's VNC capability is view-only.
class VncView extends StatefulWidget {
  const VncView({super.key, required this.session});

  final VncSession session;

  @override
  State<VncView> createState() => _VncViewState();
}

class _VncViewState extends State<VncView> {
  ui.Image? _frame;
  StreamSubscription? _frames;
  final _focus = FocusNode();
  bool _decoding = false;
  bool _dirty = false;
  int _buttons = 0;

  bool get _viewOnly => widget.session.config.viewOnly;

  @override
  void initState() {
    super.initState();
    _frames = widget.session.client.frames.listen((_) => _scheduleDecode());
    _scheduleDecode();
  }

  Future<void> _scheduleDecode() async {
    // Coalesce bursts: if a decode is in flight, mark dirty and let it
    // re-run once with the newest buffer.
    if (_decoding) {
      _dirty = true;
      return;
    }
    _decoding = true;
    do {
      _dirty = false;
      final c = widget.session.client;
      if (c.width > 0 && c.height > 0) {
        final w = c.width;
        final h = c.height;
        // Copy: the client keeps mutating its buffer.
        final copy = Uint8List.fromList(c.pixels);
        final done = Completer<void>();
        ui.decodeImageFromPixels(copy, w, h, ui.PixelFormat.rgba8888, (img) {
          if (!mounted) {
            img.dispose();
          } else {
            setState(() {
              _frame?.dispose();
              _frame = img;
            });
          }
          done.complete();
        });
        await done.future;
      }
    } while (_dirty);
    _decoding = false;
  }

  @override
  void dispose() {
    _frames?.cancel();
    _focus.dispose();
    _frame?.dispose();
    super.dispose();
  }

  // ---- input ------------------------------------------------------------

  int _maskFor(int buttons) {
    var mask = 0;
    if (buttons & kPrimaryMouseButton != 0) mask |= 1;
    if (buttons & kMiddleMouseButton != 0) mask |= 2;
    if (buttons & kSecondaryMouseButton != 0) mask |= 4;
    return mask;
  }

  void _pointer(int x, int y, int mask) {
    if (_viewOnly) return;
    _buttons = mask;
    widget.session.client.sendPointer(x, y, mask);
  }

  void _wheel(double dy, int x, int y) {
    if (_viewOnly) return;
    final bit = dy < 0 ? 8 : 16; // wheel up / wheel down
    final c = widget.session.client;
    c.sendPointer(x, y, _buttons | bit);
    c.sendPointer(x, y, _buttons);
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent e) {
    if (_viewOnly) return KeyEventResult.ignored;
    if (e is KeyDownEvent || e is KeyUpEvent) {
      final keysym = keysymFor(e.logicalKey, character: e.character);
      if (keysym == null) return KeyEventResult.ignored;
      widget.session.client.sendKey(keysym, down: e is KeyDownEvent);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  // ---- view -------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final c = widget.session.client;
    if (c.width == 0 || c.height == 0) {
      return const Center(child: CircularProgressIndicator());
    }
    return ColoredBox(
      color: Colors.black,
      child: InteractiveViewer(
        constrained: false,
        maxScale: 4,
        minScale: 0.2,
        child: SizedBox(
          width: c.width.toDouble(),
          height: c.height.toDouble(),
          child: Focus(
            focusNode: _focus,
            autofocus: true,
            onKeyEvent: _onKey,
            child: Listener(
              onPointerDown: (e) => _pointer(
                e.localPosition.dx.round(),
                e.localPosition.dy.round(),
                _maskFor(e.buttons),
              ),
              onPointerMove: (e) => _pointer(
                e.localPosition.dx.round(),
                e.localPosition.dy.round(),
                _maskFor(e.buttons),
              ),
              onPointerUp: (e) => _pointer(
                e.localPosition.dx.round(),
                e.localPosition.dy.round(),
                0,
              ),
              onPointerSignal: (e) {
                if (e is PointerScrollEvent) {
                  _wheel(e.scrollDelta.dy, e.localPosition.dx.round(),
                      e.localPosition.dy.round());
                }
              },
              child: CustomPaint(
                painter: _FramePainter(_frame),
                child: _frame == null
                    ? const Center(child: CircularProgressIndicator())
                    : null,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FramePainter extends CustomPainter {
  const _FramePainter(this.image);

  final ui.Image? image;

  @override
  void paint(Canvas canvas, Size size) {
    final img = image;
    if (img == null) return;
    canvas.drawImageRect(
      img,
      Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
      Offset.zero & size,
      Paint()..filterQuality = FilterQuality.low,
    );
  }

  @override
  bool shouldRepaint(_FramePainter old) => old.image != image;
}
