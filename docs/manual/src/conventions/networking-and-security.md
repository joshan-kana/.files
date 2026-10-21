# Networking and security

**Convention:** Expose only what a feature actually requires. Keep network boundaries, authentication, firewall rules, and credential delivery explicit and with their semantic owners.

## Network exposure

The home server's normal application exposure boundary is its LAN, with Tailscale providing remote access through the centrally configured route. Where supported, native services bind to the configured LAN address, and service-specific ports open only on the intended LAN interface.

- Reuse shared `config.dotfiles.server.lan` settings instead of inventing duplicated host addresses.
- Do not add app-specific `tailscale0` firewall rules; Tailscale trust belongs to the server networking scope.
- OCI published ports bind **host-side** to the intended address. The internal container port stays the upstream default unless the application is actually reconfigured.
- A public authenticated endpoint is an explicit exception, not the default deployment pattern.
- Roaming hostnames, DHCP, local DNS, and Tailscale fallback are shared networking concerns. Avoid per-app DNS workarounds.

These choices are server-specific policy, not universal assumptions about every NixOS host.

## Secrets and privilege

- Store credentials outside Git, generated documentation, and the Nix store; runtime services receive paths, environment files, or systemd credentials.
- Evaluation and builds must not probe the contents or presence of runtime secret files.
- Missing **required** credentials should cause clear runtime failure, with `AssertPathExists` or the service's supported validation mechanism when appropriate.
- Optional credentials gate only the optional feature consuming them.
- Restrict services to the identities and permissions they need. Do not expand a shared MCP gateway's privileges merely because a separate shell-access service requires sudo or SSH.
- Avoid secrets in logs, commit metadata, error messages, and build arguments.

## Review and enforcement

Review listeners, firewall interfaces, authentication paths, service identities, and credential handling together. The existing [server-app standards test](https://github.com/joshan-kana/.files/blob/main/tests/server-app-standards.nix) asserts some of these evaluated policies; it is not a substitute for a live port and authorization check after deployment.

See the cross-project [Networking](https://github.com/joshan-kana/infrastructure-docs/blob/main/docs/NETWORKING.md) and [Secrets](https://github.com/joshan-kana/infrastructure-docs/blob/main/docs/SECRETS.md) policies for the broader design.
