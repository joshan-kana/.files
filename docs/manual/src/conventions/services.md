# Services

The owning application scope controls service lifecycle, identities, permissions, storage, dependencies, credential delivery, network exposure, and backup coverage.

## Lifecycle

Prefer an existing native service module when it supports the required behavior. Otherwise choose the simplest reliable supported execution mechanism, including containers where appropriate.

Required runtime prerequisites must fail clearly when absent. Optional integrations may be gated on their own optional dependencies; credential handling follows [networking and security](networking-and-security.md).

Keep application-specific service and backup declarations with the application; consume shared storage, networking and authentication policy from their owners.

Keep scheduling and dependency supervision in the native service manager when available. Use native units, timers, paths, and readiness dependencies rather than hiding a second background supervisor inside a shell script. Prefer event-driven signals to redundant periodic checks; bound retries when a required external service can appear after startup.

## State and permissions

Prefer declarative service users/groups, systemd-managed directories, and tmpfiles to repeated imperative startup repairs. Use named service identities for persistent data rather than hard-coded numeric IDs. Account for persistent identity databases in recovery when identities depend on them.

Reuse configurable values where several service settings must agree. Retain independent upstream defaults.

Keep mutable application records and business state in the application's supported interface instead of reproducing them as Nix configuration.

## Verification

Validate service behavior and effective configuration as described in [validation](validation.md).
