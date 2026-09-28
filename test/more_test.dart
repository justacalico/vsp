import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vsp/models/machine.dart';
import 'package:vsp/models/protocol_kind.dart';
import 'package:vsp/protocols/protocol_driver.dart';
import 'package:vsp/protocols/protocol_registry.dart';
import 'package:vsp/protocols/remote_session.dart';
import 'package:vsp/protocols/vnc/keysyms.dart';
import 'package:vsp/protocols/vnc/rfb_channel.dart';

void main() {
  group('keysyms', () {
    test('printable characters map to latin-1 codepoints', () {
      expect(keysymFor(LogicalKeyboardKey.keyA, character: 'a'), 0x61);
      expect(keysymFor(LogicalKeyboardKey.digit1, character: '1'), 0x31);
      expect(keysymFor(LogicalKeyboardKey.space, character: ' '), 0x20);
    });

    test('named keys', () {
      expect(keysymFor(LogicalKeyboardKey.enter), 0xFF0D);
      expect(keysymFor(LogicalKeyboardKey.escape), 0xFF1B);
      expect(keysymFor(LogicalKeyboardKey.arrowLeft), 0xFF51);
      expect(keysymFor(LogicalKeyboardKey.backspace), 0xFF08);
      expect(keysymFor(LogicalKeyboardKey.shiftLeft), 0xFFE1);
      expect(keysymFor(LogicalKeyboardKey.f5), 0xFFBE + 4);
      expect(keysymFor(LogicalKeyboardKey.f12), 0xFFBE + 11);
    });

    test('unmapped returns null', () {
      expect(keysymFor(LogicalKeyboardKey.audioVolumeUp), isNull);
    });
  });

  group('PlannedDriver', () {
    test('is not implemented and refuses connect', () {
      final d = PlannedDriver(ProtocolKind.rdp, 'soon');
      expect(d.isImplemented, isFalse);
      expect(d.comingSoonNote, 'soon');
      final m = Machine(id: 'x', name: 'n', host: 'h');
      expect(d.connect(m, {}), throwsA(isA<UnsupportedError>()));
    });
  });

  group('ProtocolDriver default', () {
    test('isImplemented defaults true', () {
      final d = _StubDriver();
      expect(d.isImplemented, isTrue);
      expect(d.comingSoonNote, '');
    });
  });

  group('rfb_channel_io', () {
    test('default connector speaks over a real socket', () async {
      final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      final seen = <int>[];
      final done = Completer<void>();
      server.listen((client) {
        client.listen((d) {
          seen.addAll(d);
          client.close();
        });
      });
      final channel = await defaultConnector('127.0.0.1', server.port);
      channel.add([1, 2, 3]);
      await done.future.timeout(
          const Duration(milliseconds: 500), onTimeout: () {});
      await channel.close();
      await server.close();
      expect(seen, isNotEmpty);
    });
  });

  group('RemoteSession', () {
    test('emit tracks phase and streams statuses', () async {
      final s = _StubSession();
      final statuses = <SessionPhase>[];
      s.status.listen((st) => statuses.add(st.phase));
      s.emit(SessionPhase.connected);
      s.emit(SessionPhase.failed, 'boom');
      await pumpEventQueue();
      expect(s.phase, SessionPhase.failed);
      expect(statuses, [SessionPhase.connected, SessionPhase.failed]);
      await s.dispose();
    });
  });
}

class _StubDriver extends ProtocolDriver {
  @override
  ProtocolKind get kind => ProtocolKind.ssh;

  @override
  Future<RemoteSession> connect(
          Machine machine, Map<String, String> secrets) async =>
      _StubSession();
}

class _StubSession extends RemoteSession {
  _StubSession() : super(Machine(id: 'x', name: 'n', host: 'h'), ProtocolKind.ssh);

  @override
  Future<void> close() async => emit(SessionPhase.closed);
}
