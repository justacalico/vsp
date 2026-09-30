import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../models/protocol_kind.dart';
import '../protocols/remote_session.dart';
import '../protocols/ssh/ssh_session.dart';
import '../protocols/vnc/vnc_session.dart';
import '../security/vault.dart';
import 'sftp_view.dart';
import 'ssh_terminal_view.dart';
import 'vnc_view.dart';
import 'widgets.dart';

/// Full-screen host for a live session. Picks the right view for the
/// protocol and keeps it alive while the session object lives in
/// [AppState] — navigating back doesn't kill the connection.
class SessionHost extends StatelessWidget {
  const SessionHost({super.key, required this.session});

  final RemoteSession session;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<SessionStatus>(
      stream: session.status,
      initialData: SessionStatus(session.phase, session.message),
      builder: (context, snap) {
        final status = snap.data ?? SessionStatus(session.phase);
        return Scaffold(
          appBar: AppBar(
            title: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(session.machine.name),
                const SizedBox(width: 8),
                _PhaseChip(status: status),
              ],
            ),
            actions: [
              if (session is SshSession &&
                  (session as SshSession).config.sftp)
                IconButton(
                  icon: const Icon(Icons.folder_open_rounded),
                  tooltip: 'Files (SFTP)',
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          SftpView(session: session as SshSession),
                    ),
                  ),
                ),
              IconButton(
                icon: const Icon(Icons.power_settings_new_rounded),
                tooltip: 'Disconnect',
                onPressed: () async {
                  final state = context.read<AppState>();
                  Navigator.of(context).maybePop();
                  await state
                      .disconnect(state.sessionId(session.machine.id, session.kind));
                },
              ),
            ],
          ),
          body: _body(status),
        );
      },
    );
  }

  Widget _body(SessionStatus status) {
    switch (status.phase) {
      case SessionPhase.connecting:
        return const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Connecting…'),
            ],
          ),
        );
      case SessionPhase.failed:
        return _FailureView(session: session, status: status);
      case SessionPhase.closed:
        return const Center(child: Text('Session closed'));
      case SessionPhase.connected:
        return switch (session) {
          SshSession s => SshTerminalView(session: s),
          VncSession s => VncView(session: s),
          _ => const Center(child: Text('Unknown session type')),
        };
    }
  }
}

/// Failed-session body: what we tried to reach, why it failed, and a
/// retry that swaps this route for the fresh session.
class _FailureView extends StatelessWidget {
  const _FailureView({required this.session, required this.status});

  final RemoteSession session;
  final SessionStatus status;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final machine = session.machine;
    final target =
        '${machine.host}:${machine.configFor(session.kind).port}';
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 40, color: scheme.error),
            const SizedBox(height: 12),
            Text('Connection failed',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text('${session.kind.label} · $target',
                style: TextStyle(
                  fontFamily: 'JetBrains Mono',
                  fontSize: 12,
                  color: scheme.onSurface.withValues(alpha: 0.55),
                )),
            if (status.message != null) ...[
              const SizedBox(height: 12),
              Text(status.message!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: scheme.onSurface.withValues(alpha: 0.75))),
            ],
            const SizedBox(height: 20),
            FilledButton.tonalIcon(
              onPressed: () => _retry(context),
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _retry(BuildContext context) async {
    final state = context.read<AppState>();
    final machine = session.machine;
    if (machine.locked && !state.isUnlocked(machine.id)) {
      final pw = await askPassword(context,
          title: 'Unlock ${machine.name}');
      if (pw == null || !context.mounted) return;
      if (!await state.unlockMachine(machine.id, pw)) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Wrong vault password')));
        }
        return;
      }
    }
    await state.disconnect(state.sessionId(machine.id, session.kind));
    try {
      final next = await state.connect(machine, session.kind);
      if (!context.mounted) return;
      unawaited(Navigator.of(context).pushReplacement(MaterialPageRoute(
          builder: (_) => SessionHost(session: next))));
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
}

class _PhaseChip extends StatelessWidget {
  const _PhaseChip({required this.status});

  final SessionStatus status;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (label, color) = switch (status.phase) {
      SessionPhase.connecting => ('connecting', scheme.primary),
      SessionPhase.connected => ('live', const Color(0xFF30D158)),
      SessionPhase.failed => ('failed', scheme.error),
      SessionPhase.closed => ('closed', scheme.onSurface.withValues(alpha: 0.4)),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
            fontSize: 11, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }
}
