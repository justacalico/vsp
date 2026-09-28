import 'dart:async';
import 'dart:typed_data';

import 'package:dartssh2/dartssh2.dart';
import 'package:xterm/xterm.dart';

import '../../models/capability.dart';
import '../../models/machine.dart';
import '../../models/protocol_kind.dart';
import '../remote_session.dart';

/// A live SSH connection. Owns the [SSHClient] and lets the UI open a
/// shell on an xterm [Terminal], or grab an SFTP client for the file
/// browser.
class SshSession extends RemoteSession {
  SshSession(Machine machine, this.client) : super(machine, ProtocolKind.ssh);

  final SSHClient client;
  final List<SSHSession> _channels = [];
  SftpClient? _sftp;

  SshConfig get config => machine.configFor(ProtocolKind.ssh) as SshConfig;

  /// Attach an interactive shell to [terminal]. Output flows into the
  /// terminal; terminal input and resizes flow back to the channel.
  Future<void> attachShell(Terminal terminal) async {
    final channel = await client.shell(
      pty: SSHPtyConfig(
        type: 'xterm-256color',
        width: terminal.viewWidth,
        height: terminal.viewHeight,
      ),
    );
    _channels.add(channel);

    terminal.onOutput = (data) {
      channel.stdin.add(Uint8List.fromList(data.codeUnits));
    };
    terminal.onResize = (w, h, pw, ph) {
      channel.resizeTerminal(w, h);
    };
    channel.stdout
        .listen((data) => terminal.write(String.fromCharCodes(data)));
    channel.stderr
        .listen((data) => terminal.write(String.fromCharCodes(data)));
    unawaited(channel.done.then((_) => emit(SessionPhase.closed)));
  }

  /// Lazily opened SFTP client for the file browser.
  Future<SftpClient> sftp() async => _sftp ??= await client.sftp();

  /// Run a one-shot command and collect stdout. Used for deploying
  /// public keys and probing the machine.
  Future<String> exec(String command) async {
    final out = await client.run(command);
    return String.fromCharCodes(out);
  }

  /// Append [publicKeyLine] to the remote user's authorized_keys.
  /// Idempotent — checks for the exact line first.
  Future<void> deployKey(String publicKeyLine) async {
    final escaped = publicKeyLine.replaceAll("'", r"'\''");
    await exec(
      "mkdir -p ~/.ssh && chmod 700 ~/.ssh && touch ~/.ssh/authorized_keys && "
      "chmod 600 ~/.ssh/authorized_keys && "
      "grep -qxF '$escaped' ~/.ssh/authorized_keys || echo '$escaped' >> ~/.ssh/authorized_keys",
    );
  }

  /// Probe OS info for the machine detail card.
  Future<String> describeHost() => exec(
      'echo "\$(uname -s) \$(uname -rm)" 2>/dev/null || ver');

  @override
  Future<void> close() async {
    for (final c in _channels) {
      c.close();
    }
    client.close();
    emit(SessionPhase.closed);
  }
}
