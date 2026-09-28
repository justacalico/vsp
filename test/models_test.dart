import 'package:flutter_test/flutter_test.dart';
import 'package:vsp/models/capability.dart';
import 'package:vsp/models/machine.dart';
import 'package:vsp/models/protocol_kind.dart';
import 'package:vsp/models/ssh_key.dart';

void main() {
  group('ProtocolKind', () {
    test('labels, ports, availability', () {
      expect(ProtocolKind.ssh.label, 'SSH');
      expect(ProtocolKind.vnc.label, 'VNC');
      expect(ProtocolKind.rdp.label, 'RDP');
      expect(ProtocolKind.moonlight.label, 'Moonlight');
      expect(ProtocolKind.ssh.defaultPort, 22);
      expect(ProtocolKind.vnc.defaultPort, 5900);
      expect(ProtocolKind.rdp.defaultPort, 3389);
      expect(ProtocolKind.moonlight.defaultPort, 47984);
      expect(ProtocolKind.ssh.isImplemented, isTrue);
      expect(ProtocolKind.vnc.isImplemented, isTrue);
      expect(ProtocolKind.rdp.isImplemented, isFalse);
      expect(ProtocolKind.moonlight.isImplemented, isFalse);
      expect(ProtocolKind.ssh.secretKeys, contains('ssh.password'));
      expect(ProtocolKind.vnc.secretKeys, contains('vnc.password'));
      for (final k in ProtocolKind.values) {
        expect(k.description.isNotEmpty, isTrue);
      }
    });
  });

  group('CapabilityConfig', () {
    test('forKind creates one per protocol with default ports', () {
      for (final k in ProtocolKind.values) {
        final c = CapabilityConfig.forKind(k);
        expect(c.kind, k);
        expect(c.enabled, isFalse);
        expect(c.port, k.defaultPort);
      }
    });

    test('ssh roundtrip', () {
      final c = SshConfig(
          enabled: true,
          port: 2222,
          username: 'root',
          auth: SshAuth.publicKey,
          keyId: 'k1',
          sftp: false);
      final back = CapabilityConfig.fromJson(
          ProtocolKind.ssh, c.toJson()) as SshConfig;
      expect(back.port, 2222);
      expect(back.username, 'root');
      expect(back.auth, SshAuth.publicKey);
      expect(back.keyId, 'k1');
      expect(back.sftp, isFalse);
      expect(back.enabled, isTrue);
    });

    test('ssh defaults when json sparse', () {
      final c = CapabilityConfig.fromJson(ProtocolKind.ssh, {}) as SshConfig;
      expect(c.port, 22);
      expect(c.username, '');
      expect(c.auth, SshAuth.password);
      expect(c.sftp, isTrue);
    });

    test('vnc roundtrip', () {
      final c = VncConfig(enabled: true, port: 5901, viewOnly: true, shared: false);
      final back = CapabilityConfig.fromJson(
          ProtocolKind.vnc, c.toJson()) as VncConfig;
      expect(back.port, 5901);
      expect(back.viewOnly, isTrue);
      expect(back.shared, isFalse);
    });

    test('rdp/moonlight roundtrip and defaults', () {
      final rdp = CapabilityConfig.fromJson(
          ProtocolKind.rdp,
          RdpConfig(enabled: true, port: 3390, username: 'a', domain: 'W')
              .toJson()) as RdpConfig;
      expect(rdp.port, 3390);
      expect(rdp.domain, 'W');
      final moon = CapabilityConfig.fromJson(ProtocolKind.moonlight, {})
          as MoonlightConfig;
      expect(moon.resolution, '1080p');
      expect(moon.fps, 60);
    });
  });

  group('Machine', () {
    test('new machine carries all capabilities', () {
      final m = Machine(id: 'x', name: 'n', host: 'h');
      expect(m.capabilities.length, ProtocolKind.values.length);
      expect(m.usable, isEmpty);
      expect(m.locked, isFalse);
    });

    test('usable filters enabled+implemented', () {
      final m = Machine(id: 'x', name: 'n', host: 'h');
      m.capabilities[ProtocolKind.ssh]!.enabled = true;
      m.capabilities[ProtocolKind.rdp]!.enabled = true;
      expect(m.usable.map((e) => e.key).toList(), [ProtocolKind.ssh]);
      expect(m.configFor(ProtocolKind.ssh).kind, ProtocolKind.ssh);
    });

    test('json roundtrip preserves everything', () {
      final m = Machine(
          id: 'id1',
          name: 'box',
          host: '10.0.0.1',
          group: 'prod',
          notes: 'fragile',
          locked: true,
          kdfSalt: 'c2FsdA==');
      m.capabilities[ProtocolKind.vnc]!.enabled = true;
      final back = Machine.fromJson(m.toJson());
      expect(back.id, 'id1');
      expect(back.host, '10.0.0.1');
      expect(back.group, 'prod');
      expect(back.notes, 'fragile');
      expect(back.locked, isTrue);
      expect(back.kdfSalt, 'c2FsdA==');
      expect(back.capabilities[ProtocolKind.vnc]!.enabled, isTrue);
    });

    test('fromJson tolerates sparse input', () {
      final m = Machine.fromJson({'id': 'y'});
      expect(m.name, '');
      expect(m.capabilities.length, ProtocolKind.values.length);
    });

    test('copyWith overrides', () {
      final m = Machine(id: 'x', name: 'n', host: 'h');
      final m2 = m.copyWith(name: 'new', host: 'newhost', group: 'g', notes: 'nn');
      expect(m2.name, 'new');
      expect(m2.host, 'newhost');
      expect(m2.id, 'x');
    });
  });

  group('SshKeyMeta', () {
    test('labels and roundtrip', () {
      expect(SshKeyType.ed25519.label, 'Ed25519');
      expect(SshKeyType.ed25519.algorithmName, 'ssh-ed25519');
      expect(SshKeyType.rsa.algorithmName, 'ssh-rsa');
      final k = SshKeyMeta(
          id: 'i',
          name: 'deploy',
          type: SshKeyType.rsa,
          publicKey: 'ssh-rsa AAAA x',
          fingerprint: 'SHA256:abc',
          hasPassphrase: true);
      final back = SshKeyMeta.fromJson(k.toJson());
      expect(back.type, SshKeyType.rsa);
      expect(back.hasPassphrase, isTrue);
      expect(back.fingerprint, 'SHA256:abc');
    });

    test('fromJson defaults', () {
      final k = SshKeyMeta.fromJson({'id': 'z'});
      expect(k.type, SshKeyType.ed25519);
      expect(k.name, '');
    });
  });
}
