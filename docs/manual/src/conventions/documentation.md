# Documentation

Keep durable policy, operational procedures, evaluated configuration, and change history in their respective sources.

## Ownership

- **Conventions:** rules that guide future contributions and explain enduring ownership boundaries.
- **Runbooks:** procedures for installation, recovery, deployment, and troubleshooting.
- **Generated reference:** evaluated host configuration, scopes, options, package inventories, and other changeable facts.
- **Infrastructure handbook:** cross-project architecture, security/recovery policy, and accepted operating decisions.

Derive host and package inventories, paths, and other mutable configuration facts from their authoritative definitions. Link to the generated reference instead of maintaining parallel inventories.

## Manual authoring

Maintain human-written pages under `docs/manual/src/`. Generated pages belong to the documentation build output, not Git. Register navigation through the existing manual assembly rather than maintaining a competing sidebar.

Update conventions when an enduring rule changes. Record the rule and the technical rationale or exceptions needed to apply it.

Validate the manual as described in [validation](validation.md).
