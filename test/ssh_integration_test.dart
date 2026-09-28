import 'dart:io';

import 'package:flutter/material.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xterm/xterm.dart';
import 'package:vsp/app_state.dart';
import 'package:vsp/models/capability.dart';
import 'package:vsp/models/machine.dart';
import 'package:vsp/models/protocol_kind.dart';
import 'package:vsp/models/ssh_key.dart';
import 'package:vsp/protocols/remote_session.dart';
import 'package:vsp/protocols/ssh/ssh_session.dart';
import 'package:vsp/security/secure_store.dart';
import 'package:vsp/ui/sftp_view.dart';
import 'package:vsp/ui/ssh_terminal_view.dart';

import 'widget_test.dart' show wrap, sizeFor;

bool sessionsEmpty(AppState s) => s.sessions.isEmpty;

Future<void> waitPhase(RemoteSession s, SessionPhase p,
    {Duration timeout = const Duration(seconds: 15)}) async {
  final deadline = DateTime.now().add(timeout);
  while (s.phase != p) {
    if (DateTime.now().isAfter(deadline)) {
      fail('timed out waiting for $p (stuck at ${s.phase})');
    }
    await Future.delayed(const Duration(milliseconds: 100));
  }
}

/// End-to-end SSH coverage: spins a real unprivileged sshd on a high
/// port and connects with a throwaway key. Runs when VSP_SSH_TEST=1 —
/// CI installs openssh-server; locally it stays opt-in.
void main() {
  final enabled = Platform.environment['VSP_SSH_TEST'] == '1';
  if (!enabled) {
    test('skipped (set VSP_SSH_TEST=1 to run against a real sshd)', () {});
    return;
  }

  late Directory tmp;
  late Process sshd;
  late int port;
  late String clientKeyPem;
  late SshKeyMeta keyMeta;
  late AppState state;
  late Machine fixtureMachine;

  Future<int> freePort() async {
    final s = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final p = s.port;
    await s.close();
    return p;
  }

  setUpAll(() async {
    tmp = await Directory.systemTemp.createTemp('vsp_sshd');
    await Process.run('ssh-keygen',
        ['-t', 'ed25519', '-N', '', '-f', '${tmp.path}/host_key']);
    await Process.run('ssh-keygen',
        ['-t', 'ed25519', '-N', '', '-f', '${tmp.path}/client_key']);
    clientKeyPem = await File('${tmp.path}/client_key').readAsString();
    final pub = await File('${tmp.path}/client_key.pub').readAsString();
    await File('${tmp.path}/authorized_keys').writeAsString(pub);
    port = await freePort();
    await File('${tmp.path}/sshd_config').writeAsString('''
Port $port
ListenAddress 127.0.0.1
HostKey ${tmp.path}/host_key
AuthorizedKeysFile ${tmp.path}/authorized_keys
PidFile ${tmp.path}/sshd.pid
UsePAM no
PasswordAuthentication no
PubkeyAuthentication yes
PermitRootLogin no
StrictModes no
Subsystem sftp internal-sftp
LogLevel ERROR
''');
    final sshdPath = (await Process.run('bash', [
      '-c',
      'command -v sshd || echo /usr/sbin/sshd'
    ]))
        .stdout
        .toString()
        .trim();
    sshd = await Process.start(
        sshdPath, ['-D', '-f', '${tmp.path}/sshd_config', '-e']);
    await Future.delayed(const Duration(milliseconds: 800));

    SharedPreferences.setMockInitialValues({});
    state = await AppState.load(
        prefs: await SharedPreferences.getInstance(),
        secrets: MemorySecretStore());
    keyMeta = await state.importKey(clientKeyPem, name: 'test');

    fixtureMachine = await state.addMachine(name: 'ui', host: '127.0.0.1');
    (fixtureMachine.configFor(ProtocolKind.ssh) as SshConfig)
      ..enabled = true
      ..port = port
      ..username = Platform.environment['USER']!
      ..auth = SshAuth.publicKey
      ..keyId = keyMeta.id;
    await state.updateMachine(fixtureMachine);
  });

  tearDownAll(() async {
    await state.disconnectAll();
    sshd.kill();
    await tmp.delete(recursive: true);
  });

  test('key auth connects, execs, deploys, and browses sftp', () async {
    final m = await state.addMachine(name: 'fixture', host: '127.0.0.1');
    (m.configFor(ProtocolKind.ssh) as SshConfig)
      ..enabled = true
      ..port = port
      ..username = Platform.environment['USER']!
      ..auth = SshAuth.publicKey
      ..keyId = keyMeta.id;
    await state.updateMachine(m);

    final session = await state.connect(m, ProtocolKind.ssh);
    expect(session, isA<SshSession>());
    await waitPhase(session, SessionPhase.connected);
    final ssh = session as SshSession;

    // one-shot exec
    expect((await ssh.exec('echo vsp-ok')).trim(), 'vsp-ok');
    expect(await ssh.describeHost(), contains('Linux'));

    // deployKey is idempotent
    final pub = keyMeta.publicKey;
    await ssh.deployKey(pub);
    await ssh.deployKey(pub);
    final count =
        await ssh.exec('grep -cFx "${pub.trim()}" ~/.ssh/authorized_keys');
    expect(count.trim(), '1');

    // sftp lists the real filesystem
    final sftp = await ssh.sftp();
    final home = Platform.environment['HOME']!;
    final entries = await sftp.listdir('$home/.ssh');
    expect(entries.isNotEmpty, isTrue);
    expect(entries.any((e) => e.filename == 'authorized_keys'), isTrue);

    // interactive shell attaches to an xterm and echoes input
    final t = Terminal(maxLines: 50);
    await ssh.attachShell(t);
    t.onOutput?.call('echo shell-marker\n');
    await Future.delayed(const Duration(seconds: 1));
    await pumpEventQueue();
    final seen = StringBuffer();
    final lines = t.buffer.lines;
    for (var i = 0; i < lines.length; i++) {
      seen.write(lines[i].getText());
    }
    expect(seen.toString(), contains('shell-marker'));

    await state.disconnectAll();
    expect(session.phase, SessionPhase.closed);
  }, timeout: const Timeout(Duration(seconds: 90)));

  test('disconnect closes and a second connect works', () async {
    final m = await state.addMachine(name: 'fixture2', host: '127.0.0.1');
    (m.configFor(ProtocolKind.ssh) as SshConfig)
      ..enabled = true
      ..port = port
      ..username = Platform.environment['USER']!
      ..auth = SshAuth.publicKey
      ..keyId = keyMeta.id;
    await state.updateMachine(m);

    final session = await state.connect(m, ProtocolKind.ssh);
    await waitPhase(session, SessionPhase.connected);
    await state.disconnect('ssh:${m.id}');
    expect(session.phase, SessionPhase.closed);
    expect(sessionsEmpty(state), isTrue);

    final again = await state.connect(m, ProtocolKind.ssh);
    await waitPhase(again, SessionPhase.connected);
    await state.disconnectAll();
  }, timeout: const Timeout(Duration(seconds: 90)));

  test('a key not in authorized_keys fails the session', () async {
    await Process.run('ssh-keygen',
        ['-t', 'ed25519', '-N', '', '-f', '${tmp.path}/bad_key']);
    final badPem = await File('${tmp.path}/bad_key').readAsString();
    final badMeta = await state.importKey(badPem, name: 'bad');

    final m = await state.addMachine(name: 'fixture3', host: '127.0.0.1');
    (m.configFor(ProtocolKind.ssh) as SshConfig)
      ..enabled = true
      ..port = port
      ..username = Platform.environment['USER']!
      ..auth = SshAuth.publicKey
      ..keyId = badMeta.id;
    await state.updateMachine(m);
    final session = await state.connect(m, ProtocolKind.ssh);
    await waitPhase(session, SessionPhase.failed,
        timeout: const Duration(seconds: 20));
    await state.disconnectAll();
  }, timeout: const Timeout(Duration(seconds: 90)));

  group('views against the fixture', () {
    testWidgets('SftpView browses a real filesystem', (tester) async {
      sizeFor(tester, const Size(700, 600));
      // real async zone: the sftp reply's continuations need the real
      // event loop, which testWidgets fakes out by default
      await tester.runAsync(() async {
        final session = await state.connect(fixtureMachine, ProtocolKind.ssh)
            as SshSession;
        await waitPhase(session, SessionPhase.connected);
        await tester.pumpWidget(
            wrap(Scaffold(body: SftpView(session: session)), state));
        await tester.pump();
        for (var i = 0; i < 40; i++) {
          await Future.delayed(const Duration(milliseconds: 250));
          await tester.pump();
          if (find.byType(ListTile).evaluate().isNotEmpty) break;
        }
      });
      expect(find.byType(ListTile), findsWidgets);
    }, timeout: const Timeout(Duration(seconds: 60)));

    testWidgets('SshTerminalView runs a real shell', (tester) async {
      sizeFor(tester, const Size(700, 600));
      await tester.runAsync(() async {
        final session = await state.connect(fixtureMachine, ProtocolKind.ssh)
            as SshSession;
        await waitPhase(session, SessionPhase.connected);
        await tester.pumpWidget(wrap(
            Scaffold(body: SshTerminalView(session: session)), state));
        await tester.pump();
        await Future.delayed(const Duration(seconds: 3));
        await tester.pump();
      });
      expect(find.byType(SshTerminalView), findsOneWidget);
    }, timeout: const Timeout(Duration(seconds: 60)));
  });
}
