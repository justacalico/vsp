import 'capability.dart';
import 'protocol_kind.dart';

/// A managed remote machine and the protocols it speaks.
///
/// `capabilities` always contains an entry for every [ProtocolKind];
/// whether it can be used is the config's `enabled` flag. Secrets are
/// stored separately (see security/vault.dart) — this object is safe to
/// persist in plain preferences.
class Machine {
  Machine({
    required this.id,
    required this.name,
    required this.host,
    this.group,
    this.notes,
    Map<ProtocolKind, CapabilityConfig>? capabilities,
    this.locked = false,
    this.kdfSalt,
    DateTime? createdAt,
  })  : capabilities = capabilities ??
            {for (final k in ProtocolKind.values) k: CapabilityConfig.forKind(k)},
        createdAt = createdAt ?? DateTime.now();

  String id;
  String name;
  String host;
  String? group;
  String? notes;
  Map<ProtocolKind, CapabilityConfig> capabilities;

  /// Whether the secret vault for this machine is wrapped by a user
  /// password. When true, [kdfSalt] holds the base64 KDF salt and the
  /// stored blob is AES-GCM ciphertext.
  bool locked;
  String? kdfSalt;
  DateTime createdAt;

  CapabilityConfig configFor(ProtocolKind kind) => capabilities[kind]!;

  Iterable<MapEntry<ProtocolKind, CapabilityConfig>> get usable =>
      capabilities.entries.where((e) => e.value.enabled && e.key.isImplemented);

  bool get hasSecretsWorthLocking =>
      capabilities.values.any((c) => c.enabled);

  Machine copyWith({String? name, String? host, String? group, String? notes}) =>
      Machine(
        id: id,
        name: name ?? this.name,
        host: host ?? this.host,
        group: group ?? this.group,
        notes: notes ?? this.notes,
        capabilities: capabilities,
        locked: locked,
        kdfSalt: kdfSalt,
        createdAt: createdAt,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'host': host,
        'group': group,
        'notes': notes,
        'locked': locked,
        'kdfSalt': kdfSalt,
        'createdAt': createdAt.toIso8601String(),
        'capabilities': {
          for (final e in capabilities.entries) e.key.name: e.value.toJson(),
        },
      };

  static Machine fromJson(Map<String, dynamic> json) {
    final caps = <ProtocolKind, CapabilityConfig>{
      for (final k in ProtocolKind.values) k: CapabilityConfig.forKind(k),
    };
    final rawCaps = json['capabilities'] as Map<String, dynamic>? ?? {};
    for (final e in rawCaps.entries) {
      final kind = ProtocolKind.values.asNameMap()[e.key];
      if (kind != null && e.value is Map<String, dynamic>) {
        caps[kind] = CapabilityConfig.fromJson(kind, e.value);
      }
    }
    return Machine(
      id: json['id'] as String,
      name: json['name'] as String? ?? '',
      host: json['host'] as String? ?? '',
      group: json['group'] as String?,
      notes: json['notes'] as String?,
      capabilities: caps,
      locked: json['locked'] == true,
      kdfSalt: json['kdfSalt'] as String?,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? ''),
    );
  }
}
