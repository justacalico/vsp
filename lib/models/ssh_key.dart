/// Which algorithm a stored SSH keypair uses.
enum SshKeyType { ed25519, rsa }

extension SshKeyTypeInfo on SshKeyType {
  String get label => switch (this) {
        SshKeyType.ed25519 => 'Ed25519',
        SshKeyType.rsa => 'RSA',
      };

  String get algorithmName => switch (this) {
        SshKeyType.ed25519 => 'ssh-ed25519',
        SshKeyType.rsa => 'ssh-rsa',
      };
}

/// Public metadata for a stored SSH keypair. The private half never
/// appears here — it lives in secure storage under `key:<id>`.
class SshKeyMeta {
  SshKeyMeta({
    required this.id,
    required this.name,
    required this.type,
    required this.publicKey,
    required this.fingerprint,
    this.hasPassphrase = false,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  String id;
  String name;
  SshKeyType type;

  /// Full OpenSSH public line, e.g. `ssh-ed25519 AAAA… comment`.
  String publicKey;

  /// `SHA256:…` fingerprint of the public blob.
  String fingerprint;

  /// Whether the private key PEM itself is passphrase-encrypted.
  bool hasPassphrase;
  DateTime createdAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'type': type.name,
        'publicKey': publicKey,
        'fingerprint': fingerprint,
        'hasPassphrase': hasPassphrase,
        'createdAt': createdAt.toIso8601String(),
      };

  static SshKeyMeta fromJson(Map<String, dynamic> json) => SshKeyMeta(
        id: json['id'] as String,
        name: json['name'] as String? ?? '',
        type: SshKeyType.values.asNameMap()[json['type']] ?? SshKeyType.ed25519,
        publicKey: json['publicKey'] as String? ?? '',
        fingerprint: json['fingerprint'] as String? ?? '',
        hasPassphrase: json['hasPassphrase'] == true,
        createdAt: DateTime.tryParse(json['createdAt'] as String? ?? ''),
      );
}
