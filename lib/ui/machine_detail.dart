import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../models/capability.dart';
import '../models/machine.dart';
import '../models/protocol_kind.dart';
import '../protocols/remote_session.dart';
import '../security/vault.dart';
import 'machine_editor.dart';
import 'session_host.dart';
import 'widgets.dart';

/// Everything about one machine: connect buttons per capability,
/// vault lock control, edit/delete.
class MachineDetail extends StatelessWidget {
  const MachineDetail({super.key, required this.machineId});

  final String machineId;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final m = state.machineById(machineId);
    if (m == null) {
      return const Scaffold(body: Center(child: Text('Machine removed')));
    }
    final embedded = isWide(context);
    final body = ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
      children: [
        if (!embedded) ...[
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(m.name,
                        style: Theme.of(context).textTheme.headlineSmall),
                    const SizedBox(height: 2),
                    Text(m.host,
                        style: TextStyle(
                          fontFamily: 'JetBrains Mono',
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.55),
                        )),
                  ],
                ),
              ),
            ],
          ),
        ] else
          _header(context, m),
        if (m.group != null || m.notes != null) ...[
          const SizedBox(height: 8),
          if (m.group != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text('Group · ${m.group}',
                  style: Theme.of(context).textTheme.bodySmall),
            ),
          if (m.notes != null)
            Text(m.notes!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.6))),
        ],
        const SectionLabel('Connect'),
        for (final e in m.capabilities.entries)
          if (e.value.enabled)
            _ConnectTile(machine: m, kind: e.key),
        const SectionLabel('Vault'),
        _LockTile(machine: m),
        if (embedded) const SizedBox(height: 8),
      ],
    );

    if (embedded) return Material(child: body);
    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Edit',
            onPressed: () => MachineEditor.show(context, m),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Remove',
            onPressed: () => _confirmDelete(context, m),
          ),
        ],
      ),
      body: body,
    );
  }

  Widget _header(BuildContext context, Machine m) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(m.name,
                  style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 2),
              Text(m.host,
                  style: TextStyle(
                    fontFamily: 'JetBrains Mono',
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.55),
                  )),
            ],
          ),
        ),
        IconButton(
          icon: const Icon(Icons.edit_outlined),
          tooltip: 'Edit',
          onPressed: () => MachineEditor.show(context, m),
        ),
        IconButton(
          icon: const Icon(Icons.delete_outline),
          tooltip: 'Remove',
          onPressed: () => _confirmDelete(context, m),
        ),
      ],
    );
  }

  void _confirmDelete(BuildContext context, Machine m) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Remove ${m.name}?'),
        content: const Text(
            'The machine and its saved secrets are deleted. This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () async {
              final state = context.read<AppState>();
              Navigator.pop(context);
              if (state.selectedMachineId == m.id) {
                state.selectedMachineId = null;
              }
              await state.removeMachine(m.id);
            },
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }
}

class _ConnectTile extends StatelessWidget {
  const _ConnectTile({required this.machine, required this.kind});

  final Machine machine;
  final ProtocolKind kind;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final session = state.sessionFor(machine.id, kind);
    final live = session != null &&
        (session.phase == SessionPhase.connected ||
            session.phase == SessionPhase.connecting);
    final failed = session?.phase == SessionPhase.failed;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: ProtocolBadge(kind, showLabel: true),
        title: Text(kind.isImplemented
            ? _subtitle(machine, kind)
            : kind.description),
        subtitle: failed
            ? Text(
                '${session?.message ?? 'Connection failed'} · tap to retry',
                style: TextStyle(color: VspColors.of(context).bad),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              )
            : !kind.isImplemented
                ? const Text('Not supported yet', style: TextStyle(fontSize: 12))
                : null,
        trailing: live
            ? FilledButton.tonalIcon(
                onPressed: () => _open(context, session),
                icon: const Icon(Icons.open_in_new, size: 16),
                label: const Text('Open'),
              )
            : kind.isImplemented
                ? FilledButton.tonalIcon(
                    onPressed: () => _connect(context, state),
                    icon: const Icon(Icons.bolt_rounded, size: 16),
                    label: const Text('Connect'),
                  )
                : null,
        onTap: live
            ? () => _open(context, session)
            : failed
                ? () => _connect(context, state)
                : null,
      ),
    );
  }

  String _subtitle(Machine m, ProtocolKind kind) {
    final c = m.configFor(kind);
    return switch (c) {
      SshConfig s =>
        '${s.username.isEmpty ? 'user' : s.username}@${m.host}:${s.port}',
      _ => '${m.host}:${c.port}',
    };
  }

  Future<void> _connect(BuildContext context, AppState state) async {
    if (machine.locked && !state.isUnlocked(machine.id)) {
      final pw = await askPassword(context,
          title: 'Unlock ${machine.name}');
      if (pw == null) return;
      if (!context.mounted) return;
      final ok = await state.unlockMachine(machine.id, pw);
      if (!ok) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Wrong vault password')));
        }
        return;
      }
    }
    try {
      final session = await state.connect(machine, kind);
      if (context.mounted) _open(context, session);
    } on VaultLockedException {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Machine is locked')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Connect failed: $e')));
      }
    }
  }

  void _open(BuildContext context, RemoteSession session) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => SessionHost(session: session),
    ));
  }
}

/// Lock/unlock row: on shows a green state + Lock now button; off
/// prompts for a new vault password.
class _LockTile extends StatelessWidget {
  const _LockTile({required this.machine});

  final Machine machine;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final unlocked = state.isUnlocked(machine.id);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(
          machine.locked
              ? (unlocked ? Icons.lock_open_rounded : Icons.lock_rounded)
              : Icons.no_encryption_rounded,
          color: machine.locked ? VspColors.of(context).ok : null,
        ),
        title: Text(machine.locked
            ? (unlocked ? 'Vault unlocked' : 'Vault locked')
            : 'Vault unprotected'),
        subtitle: Text(machine.locked
            ? 'Secrets need the vault password to connect'
            : 'Secrets sit in secure storage without a password'),
        trailing: machine.locked
            ? TextButton(
                onPressed: () => _unlockOrRelock(context, state, unlocked),
                child: Text(unlocked ? 'Lock now' : 'Unlock'),
              )
            : TextButton(
                onPressed: () => _protect(context, state),
                child: const Text('Protect'),
              ),
      ),
    );
  }

  Future<void> _unlockOrRelock(
      BuildContext context, AppState state, bool unlocked) async {
    if (unlocked) {
      state.lockMachine(machine.id);
      return;
    }
    final pw = await askPassword(context, title: 'Unlock ${machine.name}');
    if (pw == null || !context.mounted) return;
    if (!await state.unlockMachine(machine.id, pw) && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Wrong vault password')));
    }
  }

  Future<void> _protect(BuildContext context, AppState state) async {
    final pw = await askPassword(
      context,
      title: 'Protect ${machine.name}',
      hint: 'New vault password',
      confirmLabel: 'Protect',
      confirm: true,
    );
    if (pw == null || pw.isEmpty || !context.mounted) return;
    await state.setMachineLock(machine.id, pw);
  }
}
