# Networking and security

Expose only the network surface a capability needs, and keep authentication, listener bindings, firewall rules, and credential delivery with their semantic owners.

## Network boundaries

Keep services private by default. Public ingress requires an explicit authenticated purpose and a narrowly scoped exception.

Use shared network identity, address, routing, and trust policy instead of duplicating host values or app-specific workarounds. A service owns its application listener and necessary firewall access; shared networking owns common VPN, DNS, and routing behavior.

For containers, distinguish the host-published binding from the container's internal port. Reconfiguring one does not automatically require changing the other.

## Credentials and privilege

- Keep secrets outside Git, documentation, build outputs, and the Nix store.
- Do not read runtime secret contents or require secret files to exist during evaluation or builds.
- A missing mandatory credential must produce an explicit runtime failure; an optional credential only gates the feature requiring it.
- Give each service the narrowest identities, file permissions, and privileged operations it needs.
- Do not extend privileges from a restricted interface to a more widely exposed one by convenience.
- Keep sensitive values out of logs, errors, command lines, and commit metadata.

## Verification

Review the effective listener, trusted interfaces, authorization path, firewall policy, identity, and credential handling together. Validate access from intended and unintended network paths when exposure changes.

For broader security policy, follow the [networking](https://github.com/joshan-kana/infrastructure-docs/blob/main/docs/NETWORKING.md) and [secrets](https://github.com/joshan-kana/infrastructure-docs/blob/main/docs/SECRETS.md) handbook sections.
