import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// The web build is a landing page, not the app — the real client is
/// native. Workbench-flavored: a typographic hero, a real look at what
/// the app does, then platform downloads.
class LandingScreen extends StatelessWidget {
  const LandingScreen({super.key});

  static const _repo = 'https://gitlab.com/HttpAnimations/vsp';
  static const _releases = 'https://gitlab.com/HttpAnimations/vsp/-/releases';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SelectionArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _Nav()),
            SliverToBoxAdapter(child: _Hero(theme: theme)),
            const SliverToBoxAdapter(child: _Divider()),
            SliverToBoxAdapter(child: _Protocols(theme: theme)),
            const SliverToBoxAdapter(child: _Divider()),
            SliverToBoxAdapter(child: _Steps(theme: theme)),
            const SliverToBoxAdapter(child: _Divider()),
            SliverToBoxAdapter(child: _Download(theme: theme)),
            SliverToBoxAdapter(child: _Footer(theme: theme)),
          ],
        ),
      ),
    );
  }
}

class _Nav extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 22),
      child: Row(
        children: [
          _mark(),
          const SizedBox(width: 10),
          const Text('VSP',
              style:
                  TextStyle(fontWeight: FontWeight.w700, letterSpacing: 0.5)),
          const Spacer(),
          TextButton(
            onPressed: () => launchUrl(Uri.parse(LandingScreen._repo)),
            child: const Text('Source'),
          ),
          const SizedBox(width: 8),
          FilledButton.tonal(
            onPressed: () => launchUrl(Uri.parse(LandingScreen._releases)),
            child: const Text('Download'),
          ),
        ],
      ),
    );
  }
}

Widget _mark() => Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: const Color(0xFF0A84FF),
        borderRadius: BorderRadius.circular(9),
      ),
      child: const Icon(Icons.swap_horizontal_circle_outlined,
          color: Colors.white, size: 20),
    );

class _Hero extends StatelessWidget {
  const _Hero({required this.theme});

  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 880),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 90, 28, 90),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Every machine,\none window.',
                style: theme.textTheme.displayLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  height: 1.05,
                  letterSpacing: -1.5,
                ),
              ),
              const SizedBox(height: 24),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Text(
                  'VSP keeps your SSH terminals and VNC desktops in one '
                  'place. Add a machine, flip on the protocols it speaks, '
                  'and connect — keys, passwords and known hosts are handled '
                  'for you.',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.62),
                    height: 1.5,
                  ),
                ),
              ),
              const SizedBox(height: 36),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  FilledButton.icon(
                    onPressed: () =>
                        launchUrl(Uri.parse(LandingScreen._releases)),
                    icon: const Icon(Icons.download_rounded, size: 18),
                    label: const Text('Get the app'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () =>
                        launchUrl(Uri.parse(LandingScreen._repo)),
                    icon: const Icon(Icons.code_rounded, size: 18),
                    label: const Text('Read the source'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 880),
        child: Divider(
          indent: 28,
          endIndent: 28,
          color: Theme.of(context).colorScheme.outline,
        ),
      ),
    );
  }
}

class _Protocols extends StatelessWidget {
  const _Protocols({required this.theme});

  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 880),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 64),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Speaks your protocols',
                  style: theme.textTheme.headlineMedium
                      ?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 28),
              const _ProtocolRow(
                name: 'SSH',
                detail:
                    'Full terminal with password or key auth, SFTP file browser, '
                    'ed25519/RSA keypairs generated on-device, TOFU host-key pinning.',
                available: true,
              ),
              const _ProtocolRow(
                name: 'VNC',
                detail:
                    'A pure-Dart RFB 3.8 client — VNC-auth and open security, '
                    'raw and CopyRect encodings, pointer, keyboard and clipboard.',
                available: true,
              ),
              const _ProtocolRow(
                name: 'RDP',
                detail:
                    'Windows Remote Desktop is on the roadmap — machines already '
                    'store their RDP settings for when the driver lands.',
                available: false,
              ),
              const _ProtocolRow(
                name: 'Moonlight',
                detail:
                    'Low-latency Sunshine streaming, planned. The capability '
                    'model is already in place.',
                available: false,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProtocolRow extends StatelessWidget {
  const _ProtocolRow({
    required this.name,
    required this.detail,
    required this.available,
  });

  final String name;
  final String detail;
  final bool available;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Row(
              children: [
                Icon(
                  available ? Icons.check_circle_rounded : Icons.schedule_rounded,
                  size: 15,
                  color: available
                      ? const Color(0xFF30D158)
                      : theme.colorScheme.onSurface.withValues(alpha: 0.35),
                ),
                const SizedBox(width: 8),
                Text(name,
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          Expanded(
            child: Text(
              detail,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.62),
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Steps extends StatelessWidget {
  const _Steps({required this.theme});

  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    const steps = [
      ('01', 'Add the machine', 'Name, host, done. Flip on the protocols it speaks.'),
      ('02', 'Hand it credentials', 'Passwords go in the vault — or protect the whole machine with one password. Generate an SSH key in a tap and VSP deploys it.'),
      ('03', 'Connect', 'Terminal or desktop, one tap. Sessions stay alive while you bounce between machines.'),
    ];
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 880),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 64),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Three steps in',
                  style: theme.textTheme.headlineMedium
                      ?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 24),
              for (final (n, t, d) in steps)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 56,
                        child: Text(n,
                            style: TextStyle(
                              fontFamily: 'monospace',
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.w700,
                            )),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(t,
                                style: theme.textTheme.titleSmall
                                    ?.copyWith(fontWeight: FontWeight.w700)),
                            const SizedBox(height: 4),
                            Text(d,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.onSurface
                                      .withValues(alpha: 0.62),
                                  height: 1.5,
                                )),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Download extends StatelessWidget {
  const _Download({required this.theme});

  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    const platforms = [
      ('Linux', Icons.terminal_rounded),
      ('macOS', Icons.laptop_mac_rounded),
      ('Windows', Icons.desktop_windows_rounded),
      ('Android', Icons.phone_android_rounded),
      ('iOS (AltStore)', Icons.phone_iphone_rounded),
    ];
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 880),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 64),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Runs where you do',
                  style: theme.textTheme.headlineMedium
                      ?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Text(
                'Free and open source under AGPL-3.0. Signed builds for every platform.',
                style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.62)),
              ),
              const SizedBox(height: 24),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final (name, icon) in platforms)
                    ActionChip(
                      avatar: Icon(icon, size: 16),
                      label: Text(name),
                      onPressed: () =>
                          launchUrl(Uri.parse(LandingScreen._releases)),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer({required this.theme});

  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 880),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 24, 28, 48),
          child: Row(
            children: [
              _mark(),
              const SizedBox(width: 10),
              Text('VSP — AGPL-3.0',
                  style: theme.textTheme.bodySmall?.copyWith(
                      color:
                          theme.colorScheme.onSurface.withValues(alpha: 0.5))),
              const Spacer(),
              TextButton(
                onPressed: () =>
                    launchUrl(Uri.parse(LandingScreen._repo)),
                child: const Text('GitLab'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
