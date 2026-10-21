# Semantic scopes

**Convention:** Configuration is owned by the idea it implements. Native NixOS, nix-darwin, and Home Manager namespaces describe *how* that idea is applied, not where the source file should live.

The [module registry](https://github.com/joshan-kana/.files/blob/main/modules/default.nix) names the semantic areas. Shared children are enabled by default where applicable; disabling a parent disables its descendants. Use `dotfiles.scopes.<path>.enable` for intentional inclusion or exclusion, not another toggle layer.

## Native configuration stays with its owner

An app-owned module may configure `services.*`, `systemd.*`, `users.*`, firewall rules, storage paths, and backups together. Use the `home = _: { ... };` evaluator boundary for Home Manager settings belonging to the same app.

A shared native option fragment is appropriate where interfaces are compatible. Where schemas differ between NixOS and Darwin, share underlying data and map it explicitly rather than inventing a fake common interface.

## Integrating with other scopes

Use `scopeEdits` when one semantic owner configures another. For example, `theme.scopeEdits.desktopApps.firefox` owns Firefox appearance, while the Firefox scope owns its program setup.

Extend an existing host child without replacing its shared function. Put genuinely host-only hardware or VM configuration under the host's corresponding scope. Keep `dotfiles.*` policy inputs for durable reuse, such as default browser or secret root, and prefer native options for ordinary implementation.

## Verification

Check both the shared scope and the host's counterpart, especially default enablement and user/session boundaries. Run semantic scope checks and affected host evaluations. The [generated scope reference](../configuration/scopes.md) is the current effective interface.

Exceptions are justified by semantic ownership or native platform support, not by a preference for a particular module namespace.
