# Semantic scopes

Configuration belongs to the idea, application, or capability it implements. NixOS, nix-darwin, and Home Manager option namespaces describe how the configuration is applied, not who owns it.

## Scope ownership

Keep native service options, packages, permissions, networking, and runtime settings together under their semantic owner. Shared behavior belongs in shared scopes; genuinely host-specific behavior belongs to the corresponding host scope.

Use `dotfiles.scopes.<path>.enable` to control scope inclusion. A disabled parent excludes its descendants. Native service enablement remains inside the owning scope.

Use the `home = _: { ... };` boundary for Home Manager configuration within the same capability.

## Composition and profiles

Profiles in `profiles/` compose shared capabilities and their defaults. Hosts select profiles and supply hardware and local differences. Use `editScope` for existing scopes and their declared policy, and `extendScope` for new children. Edits merge inherited attribute sets and Home Manager module contributions. Replacing a list replaces its inherited contents; merge lists explicitly when adding elements.

Register upstream module schemas through the shared native module interface for the applicable evaluator. Keep schema availability independent of optional functionality that refers to those options. Enable functionality in its semantic scope.

## Cross-scope configuration

Distinguish three responsibilities: the **policy owner** chooses a value, the **consumer** implements its runtime behavior, and the **host** supplies genuine local exceptions. A shared theme, for example, owns application color and font mappings; the application retains its controls and functional integrations. Do not move a shared policy into a consumer merely to shorten its import path.

Use `scopeEdits` when one semantic owner intentionally configures another. Apply cross-scope edits at the policy owner, addressed to the existing consumer scope, rather than introducing a parallel imported integration module or duplicating the same assignments in multiple scopes. The consumer retains responsibility for its functional configuration. Disabling an optional policy scope must not disable unrelated consumers or leave references to configuration artifacts that policy no longer generates.

Use `scopeOptions` for typed policy owned by a scope and `dotfiles.*` for durable inputs shared across scopes. Prefer native options for implementation details and host-local overrides for individual host exceptions.

Validate parent enablement, shared/host merges, and effective results on affected hosts. See the [generated scope reference](../configuration/scopes.md) for evaluated options.
