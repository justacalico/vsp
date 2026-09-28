import 'package:flutter/material.dart';
import 'package:xterm/xterm.dart';

import '../protocols/ssh/ssh_session.dart';

/// Interactive shell backed by xterm. The terminal is created once per
/// view; the SSH channel writes into it and user input flows back.
class SshTerminalView extends StatefulWidget {
  const SshTerminalView({super.key, required this.session});

  final SshSession session;

  @override
  State<SshTerminalView> createState() => _SshTerminalViewState();
}

class _SshTerminalViewState extends State<SshTerminalView> {
  late final Terminal _terminal;
  String? _error;

  @override
  void initState() {
    super.initState();
    _terminal = Terminal(maxLines: 10000);
    _attach();
  }

  Future<void> _attach() async {
    try {
      await widget.session.attachShell(_terminal);
      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Center(child: Text('Could not open shell: $_error'));
    }
    return TerminalView(
      _terminal,
      backgroundOpacity: 1,
      autofocus: true,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    );
  }
}
