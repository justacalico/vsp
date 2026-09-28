import 'protocol_kind.dart';

/// How a machine should authenticate over SSH.
enum SshAuth { password, publicKey }

/// Per-protocol configuration attached to a machine. A machine may carry
/// config for every protocol but only [enabled] ones are connectable.
///
/// Secrets never live here: anything sensitive (passwords, passphrases)
/// goes into the machine's vault blob and is referenced by name.
sealed class CapabilityConfig {
  CapabilityConfig({this.enabled = false, required this.port});

  bool enabled;
  int port;

  ProtocolKind get kind;

  Map<String, dynamic> toJson();

  static CapabilityConfig forKind(ProtocolKind kind) => switch (kind) {
        ProtocolKind.ssh => SshConfig(port: kind.defaultPort),
        ProtocolKind.vnc => VncConfig(port: kind.defaultPort),
        ProtocolKind.rdp => RdpConfig(port: kind.defaultPort),
        ProtocolKind.moonlight => MoonlightConfig(port: kind.defaultPort),
      };

  static CapabilityConfig fromJson(ProtocolKind kind, Map<String, dynamic> json) =>
      switch (kind) {
        ProtocolKind.ssh => SshConfig.fromJson(json),
        ProtocolKind.vnc => VncConfig.fromJson(json),
        ProtocolKind.rdp => RdpConfig.fromJson(json),
        ProtocolKind.moonlight => MoonlightConfig.fromJson(json),
      };

  static int _port(Map<String, dynamic> json, int fallback) =>
      (json['port'] as num?)?.toInt() ?? fallback;
}

class SshConfig extends CapabilityConfig {
  SshConfig({
    super.enabled,
    required super.port,
    this.username = '',
    this.auth = SshAuth.password,
    this.keyId,
    this.sftp = true,
  });

  String username;
  SshAuth auth;

  /// Id of a stored [SshKeyMeta] used when [auth] is publicKey.
  String? keyId;

  /// Offer an SFTP file browser alongside the terminal.
  bool sftp;

  @override
  ProtocolKind get kind => ProtocolKind.ssh;

  @override
  Map<String, dynamic> toJson() => {
        'port': port,
        'username': username,
        'auth': auth.name,
        'keyId': keyId,
        'sftp': sftp,
      };

  static SshConfig fromJson(Map<String, dynamic> json) => SshConfig(
        enabled: json['enabled'] == true,
        port: CapabilityConfig._port(json, 22),
        username: json['username'] as String? ?? '',
        auth: SshAuth.values.asNameMap()[json['auth']] ?? SshAuth.password,
        keyId: json['keyId'] as String?,
        sftp: json['sftp'] != false,
      );
}

class VncConfig extends CapabilityConfig {
  VncConfig({
    super.enabled,
    required super.port,
    this.viewOnly = false,
    this.shared = true,
  });

  /// Never send pointer/keyboard input.
  bool viewOnly;

  /// RFB shared flag: keep other clients connected.
  bool shared;

  @override
  ProtocolKind get kind => ProtocolKind.vnc;

  @override
  Map<String, dynamic> toJson() => {
        'port': port,
        'viewOnly': viewOnly,
        'shared': shared,
      };

  static VncConfig fromJson(Map<String, dynamic> json) => VncConfig(
        enabled: json['enabled'] == true,
        port: CapabilityConfig._port(json, 5900),
        viewOnly: json['viewOnly'] == true,
        shared: json['shared'] != false,
      );
}

class RdpConfig extends CapabilityConfig {
  RdpConfig({
    super.enabled,
    required super.port,
    this.username = '',
    this.domain = '',
  });

  String username;
  String domain;

  @override
  ProtocolKind get kind => ProtocolKind.rdp;

  @override
  Map<String, dynamic> toJson() => {
        'port': port,
        'username': username,
        'domain': domain,
      };

  static RdpConfig fromJson(Map<String, dynamic> json) => RdpConfig(
        enabled: json['enabled'] == true,
        port: CapabilityConfig._port(json, 3389),
        username: json['username'] as String? ?? '',
        domain: json['domain'] as String? ?? '',
      );
}

class MoonlightConfig extends CapabilityConfig {
  MoonlightConfig({
    super.enabled,
    required super.port,
    this.resolution = '1080p',
    this.fps = 60,
  });

  String resolution;
  int fps;

  @override
  ProtocolKind get kind => ProtocolKind.moonlight;

  @override
  Map<String, dynamic> toJson() => {
        'port': port,
        'resolution': resolution,
        'fps': fps,
      };

  static MoonlightConfig fromJson(Map<String, dynamic> json) => MoonlightConfig(
        enabled: json['enabled'] == true,
        port: CapabilityConfig._port(json, 47984),
        resolution: json['resolution'] as String? ?? '1080p',
        fps: (json['fps'] as num?)?.toInt() ?? 60,
      );
}
