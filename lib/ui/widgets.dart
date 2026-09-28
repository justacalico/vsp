import 'package:flutter/material.dart';

import '../models/protocol_kind.dart';

/// Form-factor breakpoint. Below this the app uses the compact layout
/// (bottom nav, pushed pages); at or above it uses the wide layout
/// (side rail, master-detail).
const kWideBreakpoint = 840.0;

bool isWide(BuildContext context) =>
    MediaQuery.sizeOf(context).width >= kWideBreakpoint;

/// Small uppercase section label, macOS settings style.
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 24, 4, 8),
      child: Text(
        text.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
              letterSpacing: 0.8,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}

/// Per-protocol glyph + tint so badges and connect buttons read at a
/// glance.
class ProtocolBadge extends StatelessWidget {
  const ProtocolBadge(this.kind, {super.key, this.showLabel = false});

  final ProtocolKind kind;
  final bool showLabel;

  static IconData icon(ProtocolKind kind) => switch (kind) {
        ProtocolKind.ssh => Icons.terminal_rounded,
        ProtocolKind.vnc => Icons.desktop_windows_rounded,
        ProtocolKind.rdp => Icons.window_rounded,
        ProtocolKind.moonlight => Icons.sports_esports_rounded,
      };

  static Color color(ProtocolKind kind) => switch (kind) {
        ProtocolKind.ssh => const Color(0xFF30D158),
        ProtocolKind.vnc => const Color(0xFF0A84FF),
        ProtocolKind.rdp => const Color(0xFF5E5CE6),
        ProtocolKind.moonlight => const Color(0xFFFF9F0A),
      };

  @override
  Widget build(BuildContext context) {
    final c = color(kind);
    final icon = Icon(ProtocolBadge.icon(kind), size: 13, color: c);
    if (!showLabel) return icon;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          icon,
          const SizedBox(width: 5),
          Text(
            kind.label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: c,
            ),
          ),
        ],
      ),
    );
  }
}

/// Empty state with icon, title, hint, and optional action.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.hint,
    this.action,
  });

  final IconData icon;
  final String title;
  final String? hint;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 320),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 44,
                color: scheme.onSurface.withValues(alpha: 0.25)),
            const SizedBox(height: 16),
            Text(title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium),
            if (hint != null) ...[
              const SizedBox(height: 6),
              Text(
                hint!,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurface.withValues(alpha: 0.55)),
              ),
            ],
            if (action != null) ...[
              const SizedBox(height: 20),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

/// Prompts for the machine's vault password. Returns the entered
/// password or null if cancelled.
Future<String?> askPassword(
  BuildContext context, {
  required String title,
  String hint = 'Vault password',
  String confirmLabel = 'Unlock',
  bool confirm = false,
}) {
  final controller = TextEditingController();
  final confirmController = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: controller,
            obscureText: true,
            autofocus: true,
            decoration: InputDecoration(hintText: hint),
            onSubmitted: (_) =>
                Navigator.pop(context, controller.text),
          ),
          if (confirm) ...[
            const SizedBox(height: 12),
            TextField(
              controller: confirmController,
              obscureText: true,
              decoration: const InputDecoration(hintText: 'Repeat it'),
              onSubmitted: (_) =>
                  Navigator.pop(context, controller.text),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            if (confirm && controller.text != confirmController.text) {
              ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Passwords do not match')));
              return;
            }
            Navigator.pop(context, controller.text);
          },
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
}

/// Signal colors for session state, readable on both themes.
class VspColors {
  VspColors._();

  static SignalColors of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? const SignalColors(
              ok: Color(0xFF30D158),
              warn: Color(0xFFFF9F0A),
              bad: Color(0xFFFF453A),
            )
          : const SignalColors(
              ok: Color(0xFF248A3D),
              warn: Color(0xFFC93400),
              bad: Color(0xFFD70015),
            );
}

class SignalColors {
  const SignalColors({required this.ok, required this.warn, required this.bad});

  final Color ok;
  final Color warn;
  final Color bad;
}
