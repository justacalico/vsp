# VSP

One window into every machine. VSP manages your SSH terminals and VNC
desktops in a single app — keys, passwords, and host fingerprints
included.

## Features

- **Machine management** — add machines once, toggle the protocols they
  speak, connect in one tap.
- **SSH** — interactive shell (xterm), password or public-key auth,
  SFTP file browser, TOFU host-key pinning.
- **VNC** — pure-Dart RFB 3.8 client (None + VNC-auth security, Raw +
  CopyRect encodings, DesktopSize resize), pointer, keyboard, and
  scroll input, view-only mode.
- **SSH keys on-device** — generate Ed25519 or RSA-3072 pairs, import
  existing OpenSSH keys, deploy to `authorized_keys` over a session.
- **Vault locking** — wrap any machine's secrets behind a password
  (Argon2id + AES-GCM). Locked machines can't connect until unlocked.
- **Designed to grow** — protocols are drivers behind a registry. RDP
  and Moonlight are modeled end-to-end already; the UI picks them up
  the moment their drivers land.
- **Web** — this site's web build is a landing page; the client is
  native on Linux, macOS, Windows, Android, and iOS (via AltStore).

## Install

Grab binaries from [Releases](https://gitlab.com/HttpAnimations/vsp/-/releases):

| Platform | Artifacts |
|---|---|
| Linux | `.tar.gz`, `.zip`, `.deb`, `.rpm`, AppImage (x86_64 + arm64) |
| Windows | `.zip` (x86_64 + arm64) |
| macOS | `.dmg`, `.zip` (Apple silicon) |
| Android | signed `.apk`, `.aab` |
| iOS | unsigned `.ipa` — add the [AltStore source](https://httpanimations.gitlab.io/vsp/altstore/apps.json) or sideload |

## Build from source

```sh
flutter pub get
flutter run          # picks up your attached device / desktop
```

Tests and coverage gate:

```sh
flutter test --coverage
```

## Architecture

```
lib/
  app_state.dart          single ChangeNotifier above MaterialApp
  models/                 Machine, per-protocol CapabilityConfig, SshKeyMeta
  protocols/
    protocol_driver.dart  connect() -> RemoteSession contract
    protocol_registry.dart  kind -> driver; planned drivers stub here
    ssh/                  dartssh2 driver, OpenSSH key codec + keygen
    vnc/                  pure-Dart RFB 3.8 client (DES auth included)
  security/               SecretStore + Argon2id/AES-GCM vault
  ui/                     adaptive scaffold, editor, sessions, landing
```

Adding a protocol = enum value + `CapabilityConfig` subclass + driver
registered in `ProtocolRegistry`. Everything else follows.

## License

AGPL-3.0 — see [LICENSE](LICENSE).
