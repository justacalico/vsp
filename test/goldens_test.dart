import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vsp/models/capability.dart';
import 'package:vsp/models/protocol_kind.dart';
import 'package:vsp/models/ssh_key.dart';
import 'package:vsp/ui/home_screen.dart';
import 'package:vsp/ui/machine_detail.dart';
import 'package:vsp/ui/keys_view.dart';
import 'package:vsp/ui/settings_view.dart';
import 'package:vsp/ui/landing_screen.dart';

import 'widget_test.dart' show makeState, wrap, sizeFor;

/// Golden screenshot pipeline — `flutter test --update-goldens` on
/// ubuntu-latest regenerates these; they double as UI regression tests
/// and as the screenshots used in docs.
void main() {
  const surfaces = {
    'compact': Size(390, 844),
    'wide': Size(1280, 800),
  };

  Future<void> shot(
    WidgetTester tester,
    Widget page,
    String name,
    Size size,
  ) async {
    sizeFor(tester, size);
    final state = await makeState();
    await tester.pumpWidget(wrap(page, state));
    await tester.pumpAndSettle();
    await expectLater(find.byType(MaterialApp),
        matchesGoldenFile('goldens/$name.png'));
  }

  group('goldens', () {
    for (final e in surfaces.entries) {
      testWidgets('home empty ${e.key}', (tester) async {
        await shot(tester, const HomeScreen(), 'home-empty-${e.key}', e.value);
      });

      testWidgets('keys empty ${e.key}', (tester) async {
        await shot(tester, const KeysView(), 'keys-empty-${e.key}', e.value);
      });

      testWidgets('settings ${e.key}', (tester) async {
        await shot(tester, const SettingsView(), 'settings-${e.key}', e.value);
      });

      testWidgets('landing ${e.key}', (tester) async {
        await shot(
            tester, const LandingScreen(), 'landing-${e.key}', e.value);
      });
    }

    testWidgets('home populated wide', (tester) async {
      const size = Size(1280, 800);
      sizeFor(tester, size);
      final s = await makeState();
      final m = await s.addMachine(name: 'truenas', host: '192.168.1.50');
      m.capabilities[ProtocolKind.ssh]!.enabled = true;
      m.capabilities[ProtocolKind.vnc]!.enabled = true;
      (m.capabilities[ProtocolKind.ssh] as SshConfig).username = 'admin';
      await s.updateMachine(m);
      final m2 = await s.addMachine(name: 'workstation', host: '10.0.0.9');
      m2.capabilities[ProtocolKind.ssh]!.enabled = true;
      await s.updateMachine(m2);
      await s.generateKey(SshKeyType.ed25519, 'deploy');
      s.selectedMachineId = m.id;

      await tester.pumpWidget(wrap(const HomeScreen(), s));
      await tester.pumpAndSettle();
      await expectLater(find.byType(MaterialApp),
          matchesGoldenFile('goldens/home-populated-wide.png'));
    });

    testWidgets('machine detail compact', (tester) async {
      const size = Size(390, 844);
      sizeFor(tester, size);
      final s = await makeState();
      final m = await s.addMachine(name: 'truenas', host: '192.168.1.50');
      m.capabilities[ProtocolKind.ssh]!.enabled = true;
      m.capabilities[ProtocolKind.vnc]!.enabled = true;
      (m.capabilities[ProtocolKind.ssh] as SshConfig).username = 'admin';
      await s.updateMachine(m);
      s.selectedMachineId = m.id;

      await tester.pumpWidget(
          wrap(Scaffold(body: MachineDetail(machineId: m.id)), s));
      await tester.pumpAndSettle();
      await expectLater(find.byType(MaterialApp),
          matchesGoldenFile('goldens/machine-detail-compact.png'));
    });
  });
}
