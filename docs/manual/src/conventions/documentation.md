# Documentation

Write enduring decisions, constraints, rationale, and exceptions at their owning source. Keep policy separate from implementation inventories and change history.

## Ownership

- **Conventions:** rules that guide future contributions and explain enduring ownership boundaries.
- **Runbooks:** procedures for installation, recovery, deployment, and troubleshooting.
- **Generated reference:** evaluated host configuration, scopes, options, package inventories, and other changeable facts.
- **Infrastructure handbook:** cross-project architecture, security/recovery policy, and accepted operating decisions.

Link to the authoritative source instead of duplicating mutable information that can be derived from configuration.

## Manual authoring

Maintain human-written pages under `docs/manual/src/`. Generated pages belong to the documentation build output, not Git. Register navigation through the existing manual assembly rather than maintaining a competing sidebar.

A code change does not require a convention edit unless it changes the rule itself. When policy changes, write the resulting decision directly, with enough rationale and exceptions to guide future work. Comments should explain non-obvious behavior, not restate code.

Validate formatting, links, assembled navigation, and rendered pages. Keep unrelated behavior changes separate from documentation-only work.
