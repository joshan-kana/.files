# Semantic scopes

Configuration belongs to the idea, application, or capability it implements. NixOS, nix-darwin, and Home Manager option namespaces describe how the configuration is applied, not who owns it.

## Scope ownership

Keep native service options, packages, permissions, networking, and runtime settings together under their semantic owner. Shared behavior belongs in shared scopes; genuinely host-specific behavior belongs to the corresponding host scope.

Use `dotfiles.scopes.<path>.enable` to control scope inclusion. A disabled parent excludes its descendants. Do not create a second enablement mechanism for the same feature.

Use the `home = _: { ... };` boundary for Home Manager configuration owned by the same capability. Share native option fragments only when their evaluator schemas are compatible; otherwise share underlying data and map it to each platform's native interface.

## Cross-scope configuration

Use `scopeEdits` when one semantic owner intentionally configures another. The owner of a cross-cutting policy controls that policy; the consumer retains responsibility for its own functional configuration.

Reserve `dotfiles.*` options for durable, reusable policy inputs. Prefer native module options for ordinary implementation details. Avoid modifying the scope machinery to accommodate a host-local exception.

Validate parent enablement, shared/host merges, and effective results on affected hosts. See the [generated scope reference](../configuration/scopes.md) for evaluated options.
