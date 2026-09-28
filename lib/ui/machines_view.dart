import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../models/machine.dart';
import '../models/protocol_kind.dart';
import 'machine_detail.dart';
import 'machine_editor.dart';
import 'widgets.dart';

/// The machine list — a single column on compact, the left pane of
/// master-detail on wide.
class MachinesView extends StatelessWidget {
  const MachinesView({super.key, required this.detailInline});

  /// True when the parent shows [MachineDetail] beside this list (wide
  /// layout); false when selection should push a page.
  final bool detailInline;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    if (state.machines.isEmpty) {
      return EmptyState(
        icon: Icons.dns_outlined,
        title: 'No machines yet',
        hint:
            'Add a machine, pick which protocols it speaks — SSH, VNC, and more soon — and VSP handles the rest.',
        action: FilledButton.icon(
          onPressed: () => MachineEditor.show(context),
          icon: const Icon(Icons.add),
          label: const Text('Add a machine'),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
      itemCount: state.machines.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final m = state.machines[i];
        return MachineCard(
          machine: m,
          selected: detailInline && state.selectedMachineId == m.id,
          onTap: () => _open(context, m),
        );
      },
    );
  }

  void _open(BuildContext context, Machine m) {
    final state = context.read<AppState>();
    if (detailInline) {
      state.selectedMachineId = m.id;
    } else {
      state.selectedMachineId = m.id;
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => MachineDetail(machineId: m.id),
      ));
    }
  }
}

class MachineCard extends StatelessWidget {
  const MachineCard({
    super.key,
    required this.machine,
    required this.onTap,
    this.selected = false,
  });

  final Machine machine;
  final VoidCallback onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final scheme = Theme.of(context).colorScheme;
    final enabled = machine.capabilities.entries
        .where((e) => e.value.enabled)
        .map((e) => e.key)
        .toList();
    final liveSessions = ProtocolKind.values
        .where((k) => state.sessionFor(machine.id, k) != null)
        .toList();

    return Material(
      color: selected ? scheme.surfaceContainerHighest : scheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: selected ? scheme.primary : scheme.outline,
          width: selected ? 1.2 : 0.5,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              _HostBadge(name: machine.name),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            machine.name,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 15),
                          ),
                        ),
                        if (machine.locked) ...[
                          const SizedBox(width: 6),
                          Icon(
                            state.isUnlocked(machine.id)
                                ? Icons.lock_open_rounded
                                : Icons.lock_rounded,
                            size: 14,
                            color: scheme.onSurface.withValues(alpha: 0.4),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      machine.host,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: scheme.onSurface.withValues(alpha: 0.55),
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final k in enabled)
                        Padding(
                          padding: const EdgeInsets.only(left: 4),
                          child: ProtocolBadge(k),
                        ),
                    ],
                  ),
                  if (liveSessions.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.circle,
                            size: 7, color: VspColors.of(context).ok),
                        const SizedBox(width: 4),
                        Text(
                          '${liveSessions.length} live',
                          style: TextStyle(
                            fontSize: 11,
                            color: VspColors.of(context).ok,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HostBadge extends StatelessWidget {
  const _HostBadge({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final initial = name.isEmpty ? '?' : name.characters.first.toUpperCase();
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: scheme.primary.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(10),
      ),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 16,
          color: scheme.primary,
        ),
      ),
    );
  }
}
