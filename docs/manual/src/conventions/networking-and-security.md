# Networking and security

Expose only the network surface a capability needs, and keep authentication, listener bindings, firewall rules, and credential delivery with their semantic owners.

## Network boundaries

Keep services private by default. Public ingress requires an explicitly authorized, authenticated purpose and a narrowly scoped exception.

Use shared network identity, address, routing, and trust policy instead of duplicating host values or app-specific workarounds. A service owns its application listener and necessary firewall access; shared networking owns common VPN, DNS, and routing behavior.

For containers, distinguish the host-published binding from the container's internal port. Reconfiguring one does not automatically require changing the other.

## Credentials and privilege

- Keep secrets outside Git, documentation, build outputs, and the Nix store.
- Do not read runtime secret contents or require secret files to exist during evaluation or builds.
- A missing mandatory credential must produce an explicit runtime failure; an optional credential only gates the feature requiring it.
- Give each service the narrowest identities, file permissions, and privileged operations it needs.
- Keep privilege boundaries separate from network reachability and service access. A general service interface must not grant access to restricted operations.
- Keep sensitive values out of logs, errors, command lines, and commit metadata.
- Provision local account passwords through runtime account tools. Preserve restored account state rather than embedding bootstrap passwords in Nix.

Use the platform's configured privilege mechanism; on NixOS, use `run0` with Polkit rather than alternative privilege-elevation tools. Verify access from intended and unintended network paths when exposure changes.

For broader security policy, follow the [networking](https://github.com/joshan-kana/infrastructure-docs/blob/main/docs/NETWORKING.md) and [secrets](https://github.com/joshan-kana/infrastructure-docs/blob/main/docs/SECRETS.md) handbook sections.
