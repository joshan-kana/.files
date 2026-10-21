# Services

**Convention:** The application scope owns its full system integration: native service settings, identities, permissions, storage, network exposure, secrets delivery, dependencies, and backup coverage.

This page adapts the previous server-app conventions to the current semantic-scope architecture. Some defaults below specifically describe the home server; they are not universal requirements for services on other hosts.

## Lifecycle and runtime

- Prefer a native NixOS service module when it supports the deployment cleanly; otherwise use the simplest reliable mechanism, including OCI containers when appropriate.
- Enabled apps should start if requirements exist. Missing mandatory runtime secrets should produce an explicit service failure, not silently disable requested behavior. Use systemd assertions such as `AssertPathExists` where relevant.
- Keep app-owned users, groups, systemd units, firewall rules, credentials, and backups with the app. Shared infrastructure belongs to its own scope.
- Derive repeated settings from a single value. Distinguish host-side published ports from the fixed internal application port.
- Keep rich application records, dashboards, and other mutable app state inside the application's supported configuration interface rather than copying it into Nix.
- Express VM-only suppression or hardware limitations explicitly under the relevant scope.

## Permissions and ownership

Prefer declarative users/groups, systemd state directories, and tmpfiles over scripts that repeatedly run `mkdir` or `chown` at startup. Name the owning service identity, not a magic numeric UID, when dealing with persistent data. Where Userborn preserves persistent identities, its identity database is part of recovery.

## Native and container services

OCI services retain correct Docker dependencies and bind host-side published ports to the intended interface. A custom `mkServerApp` framework is not needed to write ordinary NixOS options. Fixed container ports remain literal unless the application itself is intentionally reconfigured.

The [server-app standards test](https://github.com/joshan-kana/.files/blob/main/tests/server-app-standards.nix) checks selected stable invariants (secret assertions, firewall trust, container dependencies, and secret directory permissions). Other conventions are review obligations, not an invitation to invent a source-code linter.

Related: [Networking and security](networking-and-security.md), [State and recovery](state-and-recovery.md), and [Packaging](packages.md).
