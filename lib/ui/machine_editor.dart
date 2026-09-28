import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../models/capability.dart';
import '../models/machine.dart';
import '../models/protocol_kind.dart';
import 'widgets.dart';

/// Add/edit sheet for a machine. Edits a copy of the config map, writes
/// the machine, then pushes secrets into the vault.
class MachineEditor extends StatefulWidget {
  const MachineEditor({super.key, this.machine});

  /// Null for a new machine.
  final Machine? machine;

  static Future<void> show(BuildContext context, [Machine? machine]) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom),
        child: MachineEditor(machine: machine),
      ),
    );
  }

  @override
  State<MachineEditor> createState() => _MachineEditorState();
}

class _MachineEditorState extends State<MachineEditor> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _host;
  late final TextEditingController _group;
  late final TextEditingController _notes;
  late final Map<ProtocolKind, CapabilityConfig> _caps;

  // Secret fields — written to the vault on save, never pre-filled.
  final _sshPassword = TextEditingController();
  final _vncPassword = TextEditingController();
  final _rdpPassword = TextEditingController();
  bool _saving = false;

  bool get _editing => widget.machine != null;

  @override
  void initState() {
    super.initState();
    final m = widget.machine;
    _name = TextEditingController(text: m?.name ?? '');
    _host = TextEditingController(text: m?.host ?? '');
    _group = TextEditingController(text: m?.group ?? '');
    _notes = TextEditingController(text: m?.notes ?? '');
    _caps = m == null
        ? {for (final k in ProtocolKind.values) k: CapabilityConfig.forKind(k)}
        : {
            for (final e in m.capabilities.entries)
              e.key: CapabilityConfig.fromJson(e.key, e.value.toJson()),
          };
    if (m == null) _caps[ProtocolKind.ssh]!.enabled = true;
  }

  @override
  void dispose() {
    for (final c in [_name, _host, _group, _notes, _sshPassword, _vncPassword, _rdpPassword]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scroll) => Form(
        key: _formKey,
        child: ListView(
          controller: scroll,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
          children: [
            Text(
              _editing ? 'Edit machine' : 'Add a machine',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(
                labelText: 'Name',
                hintText: 'Homelab, Workstation…',
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Give it a name' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _host,
              decoration: const InputDecoration(
                labelText: 'Host',
                hintText: '192.168.1.20 or server.example.com',
              ),
              keyboardType: TextInputType.url,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Host is required' : null,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _group,
              decoration: const InputDecoration(
                labelText: 'Group (optional)',
                hintText: 'prod, home…',
              ),
            ),
            const SectionLabel('Capabilities'),
            for (final kind in ProtocolKind.values)
              _capabilityCard(kind, state),
            const SectionLabel('Notes'),
            TextField(
              controller: _notes,
              maxLines: 3,
              minLines: 2,
              decoration: const InputDecoration(
                hintText: 'What lives here, what to watch out for…',
              ),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: Text(_editing ? 'Save changes' : 'Add machine'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _capabilityCard(ProtocolKind kind, AppState state) {
    final config = _caps[kind]!;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Column(
          children: [
            Row(
              children: [
                ProtocolBadge(kind, showLabel: true),
                const SizedBox(width: 10),
                if (!kind.isImplemented)
                  Text(
                    'coming soon',
                    style: TextStyle(
                      fontSize: 11,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.4),
                    ),
                  ),
                const Spacer(),
                Switch(
                  value: config.enabled,
                  onChanged: (v) => setState(() => config.enabled = v),
                ),
              ],
            ),
            if (config.enabled) ...[
              const Divider(),
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _capabilityFields(kind, config, state),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _capabilityFields(
      ProtocolKind kind, CapabilityConfig config, AppState state) {
    final portField = TextFormField(
      initialValue: config.port.toString(),
      decoration: const InputDecoration(labelText: 'Port'),
      keyboardType: TextInputType.number,
      onChanged: (v) => config.port = int.tryParse(v) ?? config.port,
    );
    return switch (config) {
      SshConfig c => Column(
          children: [
            Row(children: [
              Expanded(
                flex: 3,
                child: TextFormField(
                  initialValue: c.username,
                  decoration: const InputDecoration(labelText: 'Username'),
                  onChanged: (v) => c.username = v.trim(),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(child: portField),
            ]),
            const SizedBox(height: 10),
            SegmentedButton<SshAuth>(
              segments: const [
                ButtonSegment(
                    value: SshAuth.password,
                    label: Text('Password'),
                    icon: Icon(Icons.password_rounded)),
                ButtonSegment(
                    value: SshAuth.publicKey,
                    label: Text('Key'),
                    icon: Icon(Icons.key_rounded)),
              ],
              selected: {c.auth},
              onSelectionChanged: (s) => setState(() => c.auth = s.first),
            ),
            const SizedBox(height: 10),
            if (c.auth == SshAuth.password)
              TextField(
                controller: _sshPassword,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Password',
                  hintText: _editing
                      ? 'Leave blank to keep the saved one'
                      : 'Stored encrypted',
                ),
              )
            else
              DropdownButtonFormField<String>(
                initialValue: c.keyId,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'SSH key'),
                items: [
                  for (final k in state.keys)
                    DropdownMenuItem(
                      value: k.id,
                      child: SizedBox(
                        width: 260,
                        child: Text(
                          '${k.name} · ${k.fingerprint.substring(k.fingerprint.length - 12)}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                ],
                onChanged: (v) => c.keyId = v,
              ),
            const SizedBox(height: 6),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('SFTP file browser'),
              subtitle: const Text('Browse and transfer files over the same session'),
              value: c.sftp,
              onChanged: (v) => setState(() => c.sftp = v),
            ),
          ],
        ),
      VncConfig c => Column(
          children: [
            Row(children: [Expanded(child: portField)]),
            TextField(
              controller: _vncPassword,
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'VNC password',
                hintText: _editing
                    ? 'Leave blank to keep the saved one'
                    : 'If the server requires one',
              ),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('View only'),
              subtitle: const Text('Watch the desktop without sending input'),
              value: c.viewOnly,
              onChanged: (v) => setState(() => c.viewOnly = v),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Shared session'),
              subtitle: const Text('Keep other viewers connected'),
              value: c.shared,
              onChanged: (v) => setState(() => c.shared = v),
            ),
          ],
        ),
      RdpConfig c => Column(
          children: [
            Row(children: [
              Expanded(
                flex: 3,
                child: TextFormField(
                  initialValue: c.username,
                  decoration: const InputDecoration(labelText: 'Username'),
                  onChanged: (v) => c.username = v.trim(),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(child: portField),
            ]),
            const SizedBox(height: 10),
            TextField(
              controller: _rdpPassword,
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'Password',
                hintText: _editing
                    ? 'Leave blank to keep the saved one'
                    : 'Stored encrypted',
              ),
            ),
          ],
        ),
      MoonlightConfig c => Row(
          children: [
            Expanded(child: portField),
            const SizedBox(width: 10),
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: c.resolution,
                decoration: const InputDecoration(labelText: 'Resolution'),
                items: const [
                  DropdownMenuItem(value: '720p', child: Text('720p')),
                  DropdownMenuItem(value: '1080p', child: Text('1080p')),
                  DropdownMenuItem(value: '1440p', child: Text('1440p')),
                  DropdownMenuItem(value: '4K', child: Text('4K')),
                ],
                onChanged: (v) => c.resolution = v ?? c.resolution,
              ),
            ),
          ],
        ),
    };
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    final state = context.read<AppState>();
    try {
      final Machine m;
      if (_editing) {
        m = widget.machine!
          ..name = _name.text.trim()
          ..host = _host.text.trim()
          ..group = _group.text.trim().isEmpty ? null : _group.text.trim()
          ..notes = _notes.text.trim().isEmpty ? null : _notes.text.trim()
          ..capabilities = _caps;
        await state.updateMachine(m);
      } else {
        m = await state.addMachine(
            name: _name.text.trim(), host: _host.text.trim());
        m.group = _group.text.trim().isEmpty ? null : _group.text.trim();
        m.notes = _notes.text.trim().isEmpty ? null : _notes.text.trim();
        m.capabilities = _caps;
        await state.updateMachine(m);
      }
      // Push any freshly typed secrets into the vault.
      final sshPw = _sshPassword.text;
      if (sshPw.isNotEmpty) {
        await state.setSecret(m.id, 'ssh.password', sshPw);
      }
      final vncPw = _vncPassword.text;
      if (vncPw.isNotEmpty) {
        await state.setSecret(m.id, 'vnc.password', vncPw);
      }
      final rdpPw = _rdpPassword.text;
      if (rdpPw.isNotEmpty) {
        await state.setSecret(m.id, 'rdp.password', rdpPw);
      }
      if (mounted) {
        context.read<AppState>().selectedMachineId = m.id;
        Navigator.pop(context);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
