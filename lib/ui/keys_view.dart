import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../models/ssh_key.dart';
import 'widgets.dart';

/// SSH key management: generate, import, copy the public line, and
/// delete. Private halves stay in secure storage.
class KeysView extends StatelessWidget {
  const KeysView({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('SSH keys'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.upload_file_outlined),
            tooltip: 'Import key',
            onPressed: () => _importKey(context, state),
          ),
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Generate key',
            onPressed: () => _generateKey(context, state),
          ),
        ],
      ),
      body: state.keys.isEmpty
          ? EmptyState(
              icon: Icons.key_off_outlined,
              title: 'No keys yet',
              hint:
                  'Generate an Ed25519 pair in a tap, or import an existing OpenSSH key.',
              action: FilledButton.icon(
                onPressed: () => _generateKey(context, state),
                icon: const Icon(Icons.add),
                label: const Text('Generate a key'),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: state.keys.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, i) {
                final k = state.keys[i];
                return Card(
                  child: ListTile(
                    leading: const Icon(Icons.key_rounded),
                    title: Text(k.name),
                    subtitle: Text(
                      '${k.type.label} · ${k.fingerprint}',
                      style: const TextStyle(
                          fontFamily: 'JetBrains Mono', fontSize: 12),
                    ),
                    isThreeLine: true,
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.copy_rounded, size: 18),
                          tooltip: 'Copy public key',
                          onPressed: () => _copyPub(context, k),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, size: 18),
                          tooltip: 'Delete',
                          onPressed: () => _confirmDelete(context, state, k),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  Future<void> _copyPub(BuildContext context, SshKeyMeta k) async {
    await Clipboard.setData(ClipboardData(text: k.publicKey));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Public key copied')));
    }
  }

  Future<void> _generateKey(BuildContext context, AppState state) async {
    final name = TextEditingController();
    var type = SshKeyType.ed25519;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Generate SSH key'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SegmentedButton<SshKeyType>(
                segments: const [
                  ButtonSegment(
                      value: SshKeyType.ed25519, label: Text('Ed25519')),
                  ButtonSegment(value: SshKeyType.rsa, label: Text('RSA 3072')),
                ],
                selected: {type},
                onSelectionChanged: (s) => setState(() => type = s.first),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: name,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  hintText: 'laptop, deploy…',
                ),
                autofocus: true,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Generate'),
            ),
          ],
        ),
      ),
    );
    if (ok != true || !context.mounted) return;
    try {
      await state.generateKey(
          type, name.text.trim().isEmpty ? type.label : name.text.trim());
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Keygen failed: $e')));
      }
    }
  }

  Future<void> _importKey(BuildContext context, AppState state) async {
    final pem = TextEditingController();
    final name = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Import key'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: name,
              decoration: const InputDecoration(labelText: 'Name (optional)'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: pem,
              maxLines: 6,
              decoration: const InputDecoration(
                hintText: 'Paste an unencrypted OPENSSH PRIVATE KEY block',
                alignLabelWithHint: true,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Import'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    try {
      await state.importKey(pem.text, name: name.text.trim());
    } on FormatException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  void _confirmDelete(BuildContext context, AppState state, SshKeyMeta k) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete ${k.name}?'),
        content: const Text(
            'The private key is wiped from secure storage. Machines using it fall back to password auth.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () {
              state.removeKey(k.id);
              Navigator.pop(context);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
