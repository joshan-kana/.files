# Server app conventions

Server app modules should describe the complete app-specific system consequence of enabling an app without adding another abstraction layer around NixOS modules.

## Runtime and secrets

- Enabled apps are expected to run. Missing required runtime secrets should fail the service with a systemd assertion rather than silently skip it.
- Secrets remain runtime files under `config.dotfiles.server.secretsDir`; Nix evaluation and builds must not read or probe them.
- Name secret-path values for what they are (for example `n8nSecret`). Optional credentials should only gate the optional feature that consumes them.

## Networking

- LAN is the default app exposure boundary. Native and host-network services should bind to the LAN address when supported and open firewall ports only on `config.dotfiles.server.lan.interface`.
- Tailscale is trusted centrally by the server networking module and provides remote LAN access through the advertised subnet. App modules should not add `tailscale0` firewall rules.
- OCI published ports should bind the host side to the LAN address. A configurable/named port is the host-side port only; keep the container-side application port literal unless the application itself is deliberately reconfigured.

## Storage and ownership

- Persistent service configuration/state belongs under `config.dotfiles.server.storage.appData.root` unless a dedicated mount or upstream requirement justifies another path.
- Bulk user data belongs under `config.dotfiles.server.storage.dataRoot.path`.
- App-specific users, groups, permissions, tmpfiles, backups, firewall rules, and runtime glue belong with the app. Shared infrastructure stays in its shared module.
- Express persistent application ownership with service user/group names. Userborn preserves those filesystem identities across system generations, and its identity database is part of the server recovery backup.
- Prefer declarative systemd/tmpfiles ownership and permissions over startup `mkdir`/`chown` scripts.

## Module shape

- Prefer the native NixOS service module when it cleanly supports the deployment; otherwise use the simplest reliable mechanism.
- Derive repeated values from one source of truth rather than duplicating configurable ports or paths.
- Use `inherit` for reused semantic scopes; keep one-off option accesses inline. Keep local bindings for genuine tweakable knobs or derived values, not aliases that only shorten one expression. Tweakable knobs such as supported host ports belong in the `let` block even when referenced once so they stay easy to find and scale; fixed application constants stay literal.
- Keep VM-variant overrides explicit when an app cannot or should not run there.

## Enforcement

Keep enforcement lightweight. `nix flake check` and NixOS evaluation are the primary correctness gates. Focused evaluated tests cover only repo-wide invariants that are valuable and stable; conventions that would require a broad source-code linter or generic `mkServerApp` framework remain review rules.
