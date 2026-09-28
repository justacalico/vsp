import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vsp/app_state.dart';
import 'package:vsp/models/machine.dart';
import 'package:vsp/models/protocol_kind.dart';
import 'package:vsp/models/ssh_key.dart';
import 'package:vsp/security/secure_store.dart';
import 'package:vsp/ui/home_screen.dart';
import 'package:vsp/ui/machine_detail.dart';
import 'package:vsp/ui/machine_editor.dart';
import 'package:vsp/ui/keys_view.dart';
import 'package:vsp/ui/settings_view.dart';
import 'package:vsp/ui/landing_screen.dart';
import 'package:vsp/ui/widgets.dart';
import 'package:vsp/ui/theme.dart';

Future<AppState> makeState() async {
  SharedPreferences.setMockInitialValues({});
  return AppState.load(
      prefs: await SharedPreferences.getInstance(),
      secrets: MemorySecretStore());
}

Widget wrap(Widget child, AppState state) {
  return ChangeNotifierProvider<AppState>.value(
    value: state,
    child: MaterialApp(
      theme: VspTheme.dark(),
      home: child,
    ),
  );
}

/// Resize the test surface for a form factor.
void sizeFor(WidgetTester tester, Size size) {
  tester.view.physicalSize = size * tester.view.devicePixelRatio;
  addTearDown(tester.view.resetPhysicalSize);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('HomeScreen', () {
    testWidgets('compact empty state + bottom nav', (tester) async {
      final s = await makeState();
      sizeFor(tester, const Size(400, 800));
      await tester.pumpWidget(wrap(const HomeScreen(), s));
      await tester.pumpAndSettle();
      expect(find.text('No machines yet'), findsOneWidget);
      expect(find.text('Keys'), findsOneWidget);
      expect(find.text('Settings'), findsOneWidget);
    });

    testWidgets('wide layout shows rail + detail pane', (tester) async {
      final s = await makeState();
      sizeFor(tester, const Size(1200, 800));
      await tester.pumpWidget(wrap(const HomeScreen(), s));
      await tester.pumpAndSettle();
      expect(find.byType(NavigationRail), findsOneWidget);
      expect(find.text('Pick a machine'), findsOneWidget);
    });

    testWidgets('nav switching reaches keys and settings', (tester) async {
      final s = await makeState();
      sizeFor(tester, const Size(400, 800));
      await tester.pumpWidget(wrap(const HomeScreen(), s));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Keys'));
      await tester.pumpAndSettle();
      expect(find.text('No keys yet'), findsOneWidget);
      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();
      expect(find.text('KNOWN HOSTS'), findsOneWidget);
    });
  });

  group('MachineEditor', () {
    testWidgets('creates a machine with ssh enabled by default',
        (tester) async {
      final s = await makeState();
      sizeFor(tester, const Size(500, 900));
      await tester.pumpWidget(wrap(
          const Scaffold(body: MachineEditor()), s));
      await tester.pumpAndSettle();
      await tester.enterText(
          find.widgetWithText(TextFormField, 'Name').first, 'homelab');
      await tester.enterText(
          find.widgetWithText(TextFormField, 'Host').first, '192.168.1.5');
      await tester.scrollUntilVisible(find.text('Add machine'), 300,
          scrollable: find.descendant(
              of: find.byType(ListView),
              matching: find.byType(Scrollable)).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add machine'));
      await tester.pumpAndSettle();
      expect(s.machines, hasLength(1));
      expect(s.machines.first.name, 'homelab');
      expect(s.machines.first.configFor(ProtocolKind.ssh).enabled, isTrue);
    });

    testWidgets('toggling vnc reveals its fields', (tester) async {
      final s = await makeState();
      sizeFor(tester, const Size(500, 900));
      await tester.pumpWidget(wrap(
          const Scaffold(body: MachineEditor()), s));
      await tester.pumpAndSettle();
      final vncCard = find.ancestor(
          of: find.text('VNC'), matching: find.byType(Card)).first;
      await tester.tap(find.descendant(
          of: vncCard, matching: find.byType(Switch)));
      await tester.pumpAndSettle();
      expect(find.text('View only'), findsOneWidget);
    });

    testWidgets('validation blocks empty save', (tester) async {
      final s = await makeState();
      sizeFor(tester, const Size(500, 900));
      await tester.pumpWidget(wrap(
          const Scaffold(body: MachineEditor()), s));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('Add machine'), 300,
          scrollable: find.descendant(
              of: find.byType(ListView),
              matching: find.byType(Scrollable)).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add machine'));
      await tester.pumpAndSettle();
      expect(s.machines, isEmpty);
      // the name field is off-screen after scrolling to the button —
      // scroll back before checking its error text
      await tester.scrollUntilVisible(find.text('Name'), -300,
          scrollable: find.descendant(
              of: find.byType(ListView),
              matching: find.byType(Scrollable)).first);
      await tester.pumpAndSettle();
      expect(find.text('Give it a name'), findsOneWidget);
    });
  });

  group('MachineDetail', () {
    testWidgets('shows connect tiles for enabled capabilities',
        (tester) async {
      final s = await makeState();
      final m = Machine(id: 'm1', name: 'server', host: '10.0.0.1');
      m.capabilities[ProtocolKind.ssh]!.enabled = true;
      m.capabilities[ProtocolKind.vnc]!.enabled = true;
      await s.addMachine(name: 'x', host: 'x');
      final real = s.machines.first;
      real.name = 'server';
      real.host = '10.0.0.1';
      real.capabilities[ProtocolKind.ssh]!.enabled = true;
      real.capabilities[ProtocolKind.vnc]!.enabled = true;
      await s.updateMachine(real);

      sizeFor(tester, const Size(1200, 800));
      await tester.pumpWidget(
          wrap(MachineDetail(machineId: real.id), s));
      await tester.pumpAndSettle();
      expect(find.text('CONNECT'), findsOneWidget);
      expect(find.byType(FilledButton), findsWidgets);
      expect(find.text('VAULT'), findsOneWidget);
    });
  });

  group('KeysView', () {
    testWidgets('lists generated keys', (tester) async {
      final s = await makeState();
      await s.generateKey(SshKeyType.ed25519, 'mine');
      sizeFor(tester, const Size(400, 800));
      await tester.pumpWidget(wrap(const KeysView(), s));
      await tester.pumpAndSettle();
      expect(find.text('mine'), findsOneWidget);
      expect(find.textContaining('SHA256:'), findsOneWidget);
    });
  });

  group('SettingsView', () {
    testWidgets('shows known hosts and about', (tester) async {
      final s = await makeState();
      s.verifyHostKey('box.local', 'ssh-ed25519', 'SHA256:xyz');
      sizeFor(tester, const Size(400, 800));
      await tester.pumpWidget(wrap(const SettingsView(), s));
      await tester.pumpAndSettle();
      expect(find.text('box.local'), findsOneWidget);
      expect(find.text('VSP'), findsOneWidget);
    });
  });

  group('widgets', () {
    testWidgets('ProtocolBadge renders label', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: ProtocolBadge(ProtocolKind.ssh, showLabel: true)),
      ));
      expect(find.text('SSH'), findsOneWidget);
    });

    testWidgets('SectionLabel uppercases', (tester) async {
      await tester.pumpWidget(const MaterialApp(
          home: Scaffold(body: SectionLabel('Connect'))));
      expect(find.text('CONNECT'), findsOneWidget);
    });

    testWidgets('askPassword returns input', (tester) async {
      String? result;
      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              result = await askPassword(context, title: 'Unlock');
            },
            child: const Text('go'),
          ),
        ),
      ));
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'pw');
      await tester.tap(
          find.widgetWithText(FilledButton, 'Unlock'));
      await tester.pumpAndSettle();
      expect(result, 'pw');
    });
  });

  group('LandingScreen', () {
    testWidgets('renders hero + downloads', (tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: VspTheme.dark(),
        home: const LandingScreen(),
      ));
      await tester.pumpAndSettle();
      expect(find.textContaining('Every machine'), findsOneWidget);
      expect(find.text('Get the app'), findsOneWidget);
      expect(find.text('SSH'), findsWidgets);
      expect(find.text('Moonlight'), findsOneWidget);
    });
  });
}
