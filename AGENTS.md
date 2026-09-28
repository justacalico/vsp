# VSP

Flutter app: VNC + SSH remote client. Web build is a landing page only.

## Verify locally before finishing

```bash
flutter analyze          # zero warnings — CI fails otherwise
flutter test             # unit + widget + goldens
VSP_SSH_TEST=1 flutter test  # + real sshd integration (needs openssh)
flutter test --update-goldens test/goldens_test.dart  # after UI changes
```

Coverage gate in CI is 80% (`lcov --fail-under-lines`). The SSH-bound
views are exercised against a fixture sshd (unprivileged, high port,
key auth) inside `test/ssh_integration_test.dart`.

## Conventions

- One `AppState` over `provider`, created once in main. Navigation
  state lives on it — never rebuild it on window resize.
- Protocols plug in through `ProtocolDriver`/`RemoteSession`
  (`lib/protocols/`). RDP and Moonlight are `PlannedDriver` stubs.
- Machine secrets go through `SecureStore`; locked machines wrap their
  secrets with Argon2id + AES-256-GCM (`lib/security/vault.dart`).
- No `dart:io` in code paths that compile for web — channel I/O behind
  `RfbChannel` with an IO impl and a web stub.
- Conventional commits, type in English, subject in Simplified Chinese
  (`feat: 添加机器管理`). `.githooks/commit-msg` prefixes stray messages
  with `misc:` so `cog check` stays green. Install with
  `git config core.hooksPath .githooks`.
- Release flow: push to main → GitHub mirror → matrix build →
  nightly/tag release → synced back to a GitLab release → Pages
  (landing + AltStore source). Versions bump via cocogitto.
- Never commit keystores, passwords, or private keys. CI signing
  secrets are masked GitHub secrets; the local keystore lives at
  `~/Desktop/vsp-signing/` outside the repo.
