import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app_state.dart';
import 'widgets.dart';

/// App settings: known SSH host keys (TOFU list), sessions, about.
class SettingsView extends StatelessWidget {
  const SettingsView({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final hosts = state.knownHosts;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        automaticallyImplyLeading: false,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
        children: [
          const SectionLabel('Known hosts'),
          Card(
            child: hosts.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'No host keys trusted yet. The first time you SSH '
                      'somewhere, its fingerprint is pinned here — a changed '
                      'fingerprint blocks the connection.',
                    ),
                  )
                : Column(
                    children: [
                      for (final e in hosts.entries)
                        ListTile(
                          dense: true,
                          title: Text(e.key,
                              style:
                                  const TextStyle(fontFamily: 'monospace')),
                          subtitle: Text(e.value,
                              style: const TextStyle(
                                  fontFamily: 'monospace', fontSize: 11)),
                          trailing: IconButton(
                            icon: const Icon(Icons.close, size: 16),
                            tooltip: 'Forget',
                            onPressed: () => state.forgetHostKey(e.key),
                          ),
                          onTap: () => Clipboard.setData(
                              ClipboardData(text: e.value)),
                        ),
                    ],
                  ),
          ),
          const SectionLabel('Sessions'),
          Card(
            child: ListTile(
              leading: const Icon(Icons.power_settings_new_rounded),
              title: const Text('Disconnect all'),
              subtitle: Text('${state.sessions.length} session(s) tracked'),
              onTap: state.sessions.isEmpty ? null : state.disconnectAll,
            ),
          ),
          const SectionLabel('About'),
          Card(
            child: Column(
              children: [
                const ListTile(
                  leading: Icon(Icons.swap_horizontal_circle_outlined),
                  title: Text('VSP'),
                  subtitle: Text('VNC + SSH, one place. AGPL-3.0.'),
                ),
                ListTile(
                  leading: const Icon(Icons.code_rounded),
                  title: const Text('Source'),
                  subtitle: const Text('gitlab.com/HttpAnimations/vsp'),
                  onTap: () => launchUrl(
                      Uri.parse('https://gitlab.com/HttpAnimations/vsp')),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
