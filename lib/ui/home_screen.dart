import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import 'keys_view.dart';
import 'machine_detail.dart';
import 'machine_editor.dart';
import 'machines_view.dart';
import 'settings_view.dart';
import 'widgets.dart';

/// Adaptive root: compact gets a bottom nav and pushed routes, wide gets
/// a rail plus master-detail. The switch is purely layout — all state
/// lives in [AppState], so a resize mid-session loses nothing.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= kWideBreakpoint;
        return Scaffold(
          body: wide ? _WideBody(state: state) : _CompactBody(state: state),
          floatingActionButton: state.navIndex == 0
              ? FloatingActionButton(
                  onPressed: () => MachineEditor.show(context),
                  child: const Icon(Icons.add),
                )
              : null,
        );
      },
    );
  }
}

class _CompactBody extends StatelessWidget {
  const _CompactBody({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(child: _tab(state.navIndex)),
        NavigationBar(
          selectedIndex: state.navIndex,
          onDestinationSelected: (i) => state.navIndex = i,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.dns_outlined),
              selectedIcon: Icon(Icons.dns_rounded),
              label: 'Machines',
            ),
            NavigationDestination(
              icon: Icon(Icons.key_outlined),
              selectedIcon: Icon(Icons.key_rounded),
              label: 'Keys',
            ),
            NavigationDestination(
              icon: Icon(Icons.tune_outlined),
              selectedIcon: Icon(Icons.tune_rounded),
              label: 'Settings',
            ),
          ],
        ),
      ],
    );
  }

  Widget _tab(int i) => switch (i) {
        0 => const MachinesView(detailInline: false),
        1 => const KeysView(),
        _ => const SettingsView(),
      };
}

class _WideBody extends StatelessWidget {
  const _WideBody({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        NavigationRail(
          selectedIndex: state.navIndex,
          onDestinationSelected: (i) => state.navIndex = i,
          labelType: NavigationRailLabelType.all,
          leading: Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _AppMark(),
          ),
          destinations: const [
            NavigationRailDestination(
              icon: Icon(Icons.dns_outlined),
              selectedIcon: Icon(Icons.dns_rounded),
              label: Text('Machines'),
            ),
            NavigationRailDestination(
              icon: Icon(Icons.key_outlined),
              selectedIcon: Icon(Icons.key_rounded),
              label: Text('Keys'),
            ),
            NavigationRailDestination(
              icon: Icon(Icons.tune_outlined),
              selectedIcon: Icon(Icons.tune_rounded),
              label: Text('Settings'),
            ),
          ],
        ),
        const VerticalDivider(width: 1),
        Expanded(child: _tab(state.navIndex)),
      ],
    );
  }

  Widget _tab(int i) => switch (i) {
        0 => Row(
            children: [
              const SizedBox(width: 360, child: MachinesView(detailInline: true)),
              const VerticalDivider(width: 1),
              Expanded(
                child: state.selectedMachineId == null
                    ? const EmptyState(
                        icon: Icons.dns_outlined,
                        title: 'Pick a machine',
                        hint: 'Select a machine on the left, or add a new one.',
                      )
                    : MachineDetail(
                        key: ValueKey(state.selectedMachineId),
                        machineId: state.selectedMachineId!,
                      ),
              ),
            ],
          ),
        1 => const KeysView(),
        _ => const SettingsView(),
      };
}

class _AppMark extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary,
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Icon(Icons.swap_horizontal_circle_outlined,
          color: Colors.white, size: 24),
    );
  }
}
