# Services

The owning application scope controls service lifecycle, identities, permissions, storage, dependencies, credential delivery, network exposure, and backup coverage.

## Lifecycle

Prefer an existing native service module when it supports the required behavior. Otherwise choose the simplest reliable supported execution mechanism, including containers where appropriate.

Enabled mandatory functionality must fail clearly when prerequisites are absent. Do not silently disable a requested service because its required runtime credentials are missing. Optional integrations may be gated on their own optional dependencies.

Keep service-specific definitions and backup declarations with the application. Keep genuinely shared storage, networking, and authentication infrastructure in their respective scopes.

## State and permissions

Prefer declarative service users/groups, systemd-managed directories, and tmpfiles to repeated imperative startup repairs. Use named service identities for persistent data rather than hard-coded numeric IDs. Account for persistent identity databases in recovery when identities depend on them.

Distinguish external listener addresses and published ports from upstream internal service ports. Reuse a configurable value where multiple settings must agree; leave independent upstream defaults unchanged.

Keep mutable application records and business state in the application's supported interface instead of reproducing them as Nix configuration.

## Verification

Verify effective units, permissions, credential assertions, dependencies, network boundaries, and backup paths. Runtime behavior requires a smoke test where Nix evaluation cannot establish it. Avoid introducing a framework or general-purpose linter merely to express ordinary native service settings.
