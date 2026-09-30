import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vsp/models/capability.dart';
import 'package:vsp/models/machine.dart';
import 'package:vsp/models/protocol_kind.dart';
import 'package:vsp/protocols/remote_session.dart';
import 'package:vsp/protocols/vnc/vnc_driver.dart';
import 'package:vsp/ui/home_screen.dart';
import 'package:vsp/ui/machine_detail.dart';
import 'package:vsp/ui/session_host.dart';
import 'package:vsp/ui/theme.dart';
import 'package:vsp/ui/vnc_view.dart';
import 'package:vsp/protocols/vnc/vnc_session.dart';
import 'package:vsp/protocols/vnc/rfb_channel.dart';
import 'package:vsp/protocols/vnc/rfb_client.dart';

import 'rfb_client_test.dart' show FakeRfbServer;
import 'widget_test.dart' show makeState, wrap, sizeFor;

void main() {
  group('SessionHost', () {
    Future<VncSession> vncSession(Machine m, FakeRfbServer server) async {
      final client = RfbClient(
          host: 't',
          connector: (h, p) async {
            Future.microtask(server.banner);
            return server;
          });
      final s = VncSession(m, client);
      await client.connect();
      return s;
    }

    testWidgets('connected vnc session shows the desktop surface',
        (tester) async {
      final m = Machine(id: 'm', name: 'box', host: 'h');
      final server = FakeRfbServer();
      final session = await vncSession(m, server);
      final s = await makeState();
      await tester.pumpWidget(wrap(SessionHost(session: session), s));
      await tester.pump();
      expect(find.text('box'), findsOneWidget);
      expect(find.text('live'), findsOneWidget);
      expect(find.byType(VncView), findsOneWidget);

      await session.dispose();
    });

    testWidgets('failed session shows the error', (tester) async {
      final m = Machine(id: 'm', name: 'box', host: 'h');
      final session = VncSession(m,
          RfbClient(host: 't', connector: (h, p) => Future.error('nope')));
      final s = await makeState();
      await tester.pumpWidget(wrap(SessionHost(session: session), s));
      await tester.pump();
      expect(find.text('Connecting…'), findsOneWidget);
      session.emit(SessionPhase.failed, 'refused');
      await tester.pumpAndSettle();
      expect(find.text('refused'), findsOneWidget);
      expect(find.text('VNC · h:5900'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });

    testWidgets('retry swaps in a fresh session', (tester) async {
      final s = await makeState();
      // Fail the first attempt, answer the retry.
      var attempts = 0;
      s.registry.drivers[ProtocolKind.vnc] =
          VncDriver(connector: (h, p) async {
        if (attempts++ == 0) {
          return Future<RfbChannel>.error(StateError('refused'));
        }
        final server = FakeRfbServer();
        Future.microtask(server.banner);
        return server;
      });
      final m = await s.addMachine(name: 'box', host: 'h');
      (m.configFor(ProtocolKind.vnc) as VncConfig).enabled = true;
      await s.updateMachine(m);

      final session = await s.connect(m, ProtocolKind.vnc);
      await tester.pumpWidget(wrap(SessionHost(session: session), s));
      await tester.pump();
      expect(find.textContaining('Could not reach h:5900'),
          findsOneWidget);

      await tester.tap(find.text('Retry'));
      // VncView's decode spinner never settles under test, so pump
      // manually instead of pumpAndSettle.
      for (var i = 0;
          i < 10 && find.text('live').evaluate().isEmpty;
          i++) {
        await tester.pump();
      }
      expect(find.text('live'), findsOneWidget);
      expect(find.byType(VncView), findsOneWidget);
      expect(s.sessionFor(m.id, ProtocolKind.vnc),
          isNot(same(session)));

      await s.disconnectAll();
    });
  });

  group('machine card interactions', () {
    testWidgets('compact tap pushes the detail page', (tester) async {
      final s = await makeState();
      final m = await s.addMachine(name: 'truenas', host: '10.0.0.5');
      m.capabilities[ProtocolKind.vnc]!.enabled = true;
      await s.updateMachine(m);
      sizeFor(tester, const Size(400, 800));
      await tester.pumpWidget(wrap(const HomeScreen(), s));
      await tester.pumpAndSettle();
      await tester.tap(find.text('truenas'));
      await tester.pumpAndSettle();
      expect(find.text('CONNECT'), findsOneWidget);
    });

    testWidgets('failed tile shows the reason and retries on tap',
        (tester) async {
      final s = await makeState();
      var attempts = 0;
      s.registry.drivers[ProtocolKind.vnc] =
          VncDriver(connector: (h, p) async {
        if (attempts++ == 0) {
          return Future<RfbChannel>.error(StateError('refused'));
        }
        final server = FakeRfbServer();
        Future.microtask(server.banner);
        return server;
      });
      final m = await s.addMachine(name: 'box', host: 'h');
      (m.configFor(ProtocolKind.vnc) as VncConfig).enabled = true;
      await s.updateMachine(m);
      final session = await s.connect(m, ProtocolKind.vnc);

      sizeFor(tester, const Size(400, 800));
      await tester.pumpWidget(
          wrap(Scaffold(body: MachineDetail(machineId: m.id)), s));
      await tester.pumpAndSettle();
      expect(
          find.textContaining('Could not reach h:5900'), findsOneWidget);
      expect(find.textContaining('tap to retry'), findsOneWidget);

      // The retry pushes a SessionHost whose spinners never settle
      // under test — pump a bounded number of frames by hand.
      await tester.tap(find.textContaining('tap to retry'));
      for (var i = 0; i < 10; i++) {
        await tester.pump();
      }
      expect(s.sessionFor(m.id, ProtocolKind.vnc),
          isNot(same(session)));

      await s.disconnectAll();
    });
  });

  group('theme', () {
    test('light and dark expose the same shape', () {
      final l = VspTheme.light();
      final d = VspTheme.dark();
      expect(l.brightness, Brightness.light);
      expect(d.brightness, Brightness.dark);
      expect(l.cardTheme.shape, isA<RoundedRectangleBorder>());
      expect(d.pageTransitionsTheme, isA<PageTransitionsTheme>());
      expect(l.inputDecorationTheme.fillColor,
          isNot(d.inputDecorationTheme.fillColor));
    });
  });
}
