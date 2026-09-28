/// The remote-access protocols VSP understands.
///
/// Adding a protocol means: add a value here, add a [CapabilityConfig]
/// subclass in capability.dart, and register a driver in
/// protocol_registry.dart. Everything else (machine CRUD, editor UI,
/// connect sheet, capability badges) keys off this enum and picks the
/// new protocol up automatically.
enum ProtocolKind {
  ssh,
  vnc,
  rdp,
  moonlight,
}

extension ProtocolKindInfo on ProtocolKind {
  String get label => switch (this) {
        ProtocolKind.ssh => 'SSH',
        ProtocolKind.vnc => 'VNC',
        ProtocolKind.rdp => 'RDP',
        ProtocolKind.moonlight => 'Moonlight',
      };

  String get description => switch (this) {
        ProtocolKind.ssh => 'Terminal shell, SFTP files and key auth',
        ProtocolKind.vnc => 'Remote desktop over the RFB protocol',
        ProtocolKind.rdp => 'Windows Remote Desktop',
        ProtocolKind.moonlight => 'Low-latency game stream via Sunshine',
      };

  int get defaultPort => switch (this) {
        ProtocolKind.ssh => 22,
        ProtocolKind.vnc => 5900,
        ProtocolKind.rdp => 3389,
        ProtocolKind.moonlight => 47984,
      };

  /// Whether a working driver exists yet. RDP and Moonlight are modeled
  /// end-to-end so machines can advertise them, but connect is a stub
  /// until their drivers land.
  bool get isImplemented => switch (this) {
        ProtocolKind.ssh || ProtocolKind.vnc => true,
        _ => false,
      };

  /// Names of secrets this protocol may read from a machine vault.
  List<String> get secretKeys => switch (this) {
        ProtocolKind.ssh => const ['ssh.password', 'ssh.keyPassphrase'],
        ProtocolKind.vnc => const ['vnc.password'],
        ProtocolKind.rdp => const ['rdp.password'],
        ProtocolKind.moonlight => const ['moonlight.pin'],
      };
}
