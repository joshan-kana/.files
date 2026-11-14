# Semantic scopes

Configuration belongs to the idea, application, or capability it implements. NixOS, nix-darwin, and Home Manager option namespaces describe how the configuration is applied, not who owns it.

## Scope ownership

Keep native service options, packages, permissions, networking, and runtime settings together under their semantic owner. Shared behavior belongs in shared scopes; genuinely host-specific behavior belongs to the corresponding host scope.

Use `dotfiles.scopes.<path>.enable` to control scope inclusion. A disabled parent excludes its descendants. Do not create a second enablement mechanism for the same feature.

Use the `home = _: { ... };` boundary for Home Manager configuration owned by the same capability. Share native option fragments only when their evaluator schemas are compatible; otherwise share underlying data and map it to each platform's native interface.

## Cross-scope configuration

Distinguish three responsibilities: the **policy owner** chooses a value, the **consumer** implements its runtime behavior, and the **host** supplies genuine local exceptions. A shared theme, for example, owns application color and font mappings; the application retains its controls and functional integrations. Do not move a shared policy into a consumer merely to shorten its import path.

Use `scopeEdits` when one semantic owner intentionally configures another. Apply cross-scope edits at the policy owner, addressed to the existing consumer scope, rather than introducing a parallel imported integration module or duplicating the same assignments in multiple scopes. The consumer retains responsibility for its functional configuration.

Reserve `dotfiles.*` options for durable, reusable policy inputs. Prefer native module options for ordinary implementation details. Prefer `scopeOptions` as the typed, authoritative interface for reusable scope policy; runtime frontends consume or adapt it rather than declaring an independent competing policy schema. Avoid modifying the scope machinery to accommodate a host-local exception.

Validate parent enablement, shared/host merges, and effective results on affected hosts. See the [generated scope reference](../configuration/scopes.md) for evaluated options.
