import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vsp/models/capability.dart';
import 'package:vsp/models/machine.dart';
import 'package:vsp/models/protocol_kind.dart';
import 'package:vsp/protocols/remote_session.dart';
import 'package:vsp/ui/home_screen.dart';
import 'package:vsp/ui/session_host.dart';
import 'package:vsp/ui/theme.dart';
import 'package:vsp/ui/vnc_view.dart';
import 'package:vsp/protocols/vnc/vnc_session.dart';
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
