import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vsp/app.dart';
import 'package:vsp/models/capability.dart';
import 'package:vsp/models/machine.dart';
import 'package:vsp/models/protocol_kind.dart';
import 'package:vsp/models/ssh_key.dart';
import 'package:vsp/protocols/vnc/vnc_driver.dart';
import 'package:vsp/ui/home_screen.dart';
import 'package:vsp/ui/machine_detail.dart';
import 'package:vsp/ui/machine_editor.dart';
import 'package:vsp/ui/keys_view.dart';
import 'package:vsp/ui/settings_view.dart';
import 'package:vsp/ui/landing_screen.dart';
import 'package:vsp/ui/theme.dart';

import 'rfb_client_test.dart' show FakeRfbServer;
import 'widget_test.dart' show makeState, wrap, sizeFor;

void main() {
  group('app shell', () {
    testWidgets('VspApp boots to the machines view', (tester) async {
      sizeFor(tester, const Size(400, 800));
      final s = await makeState();
      await tester.pumpWidget(VspApp(state: s));
      await tester.pumpAndSettle();
      expect(find.text('No machines yet'), findsOneWidget);
      expect(find.byType(HomeScreen), findsOneWidget);
    });
  });

  group('MachineDetail interactions', () {
    Future<Machine> seeded(dynamic s) async {
      final m = await s.addMachine(name: 'server', host: 'h');
      m.capabilities[ProtocolKind.ssh]!.enabled = true;
      (m.capabilities[ProtocolKind.ssh] as SshConfig).username = 'me';
      await s.updateMachine(m);
      return m;
    }

    testWidgets('protect opens the password dialog', (tester) async {
      final s = await makeState();
      final m = await seeded(s);
      await tester.pumpWidget(wrap(MachineDetail(machineId: m.id), s));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Protect'));
      await tester.pumpAndSettle();
      expect(find.text('Protect server'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(m.locked, isFalse);
    });

    testWidgets('delete asks, confirm removes', (tester) async {
      final s = await makeState();
      final m = await seeded(s);
      sizeFor(tester, const Size(1200, 800));
      await tester.pumpWidget(wrap(MachineDetail(machineId: m.id), s));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Remove'));
      await tester.pumpAndSettle();
      expect(s.machines, isEmpty);
    });

    testWidgets('connect tap wires through AppState', (tester) async {
      final s = await makeState();
      s.registry.drivers[ProtocolKind.vnc] =
          VncDriver(connector: (h, p) async {
        final server = FakeRfbServer();
        Future.microtask(server.banner);
        return server;
      });
      final m = await s.addMachine(name: 'v', host: 'h');
      m.capabilities[ProtocolKind.vnc]!.enabled = true;
      await s.updateMachine(m);
      sizeFor(tester, const Size(500, 800));
      await tester.pumpWidget(
          wrap(Scaffold(body: MachineDetail(machineId: m.id)), s));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Connect'));
      await tester.pump();
      await tester.pump();
      expect(s.sessions, isNotEmpty);
      await s.disconnectAll();
    });
  });

  group('MachineEditor editing', () {
    testWidgets('prepopulates and saves changes', (tester) async {
      final s = await makeState();
      final m = await s.addMachine(name: 'old', host: '10.0.0.1');
      m.capabilities[ProtocolKind.vnc]!.enabled = true;
      await s.updateMachine(m);
      sizeFor(tester, const Size(500, 900));
      await tester.pumpWidget(
          wrap(Scaffold(body: MachineEditor(machine: m)), s));
      await tester.pumpAndSettle();
      expect(find.text('Edit machine'), findsOneWidget);
      await tester.enterText(
          find.widgetWithText(TextFormField, 'Name').first, 'new');
      await tester.scrollUntilVisible(find.text('Save changes'), 300,
          scrollable: find.descendant(
              of: find.byType(ListView),
              matching: find.byType(Scrollable)).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save changes'));
      await tester.pumpAndSettle();
      expect(s.machineById(m.id)!.name, 'new');
    });

    testWidgets('key auth shows the key selector', (tester) async {
      final s = await makeState();
      await s.generateKey(SshKeyType.ed25519, 'k1');
      sizeFor(tester, const Size(500, 900));
      await tester.pumpWidget(
          wrap(const Scaffold(body: MachineEditor()), s));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Key'));
      await tester.pumpAndSettle();
      // the list opens on tap; closed it only shows the selection
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      expect(find.textContaining('k1'), findsOneWidget);
    });
  });

  group('KeysView actions', () {
    testWidgets('generate via the sheet', (tester) async {
      final s = await makeState();
      sizeFor(tester, const Size(400, 800));
      await tester.pumpWidget(wrap(const KeysView(), s));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Generate a key'));
      await tester.pumpAndSettle();
      expect(find.text('Generate SSH key'), findsOneWidget);
      await tester.enterText(find.byType(TextField).first, 'deploy');
      await tester.tap(find.widgetWithText(FilledButton, 'Generate'));
      await tester.pumpAndSettle();
      expect(s.keys, hasLength(1));
      expect(s.keys.first.name, 'deploy');
    });

    testWidgets('delete asks then removes', (tester) async {
      final s = await makeState();
      await s.generateKey(SshKeyType.ed25519, 'gone');
      sizeFor(tester, const Size(400, 800));
      await tester.pumpWidget(wrap(const KeysView(), s));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await tester.pumpAndSettle();
      expect(s.keys, isEmpty);
    });
  });

  group('SettingsView actions', () {
    testWidgets('forget a pinned host', (tester) async {
      final s = await makeState();
      s.verifyHostKey('box.local', 'ssh-ed25519', 'SHA256:xyz');
      sizeFor(tester, const Size(400, 800));
      await tester.pumpWidget(wrap(const SettingsView(), s));
      await tester.pumpAndSettle();
      expect(find.text('box.local'), findsOneWidget);
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();
      expect(s.knownHosts, isEmpty);
    });
  });

  group('landing page', () {
    testWidgets('has protocol cards and platforms row', (tester) async {
      sizeFor(tester, const Size(1280, 800));
      await tester.pumpWidget(MaterialApp(
          theme: VspTheme.dark(), home: const LandingScreen()));
      await tester.pumpAndSettle();
      expect(find.text('Speaks your protocols'), findsOneWidget);
      expect(find.text('RDP'), findsOneWidget);
      expect(find.text('Moonlight'), findsOneWidget);
    });
  });
}
