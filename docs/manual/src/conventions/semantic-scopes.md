# Semantic scopes

Configuration belongs to the idea, application, or capability it implements. NixOS, nix-darwin, and Home Manager option namespaces describe how the configuration is applied, not who owns it.

## Scope ownership

Keep native service options, packages, permissions, networking, and runtime settings together under their semantic owner. Shared behavior belongs in shared scopes; genuinely host-specific behavior belongs to the corresponding host scope.

Use `dotfiles.scopes.<path>.enable` to control scope inclusion. A disabled parent excludes its descendants. Do not create a second enablement mechanism for the same feature.

Use the `home = _: { ... };` boundary for Home Manager configuration owned by the same capability. Share native option fragments only when their evaluator schemas are compatible; otherwise share underlying data and map it to each platform's native interface.

## Composition and profiles

Profiles in `profiles/` select shared capabilities and their defaults. Hosts compose the appropriate profiles and supply hardware and genuine local differences. Use `editScope` to augment an existing scope or its declared policy and `extendScope` to introduce an actual new child. A profile or platform condition is not a separate implementation hierarchy.

Register upstream modules at their existing shared registration boundary. Enable functionality within its semantic owner rather than treating availability of a native module as enablement.

## Cross-scope configuration

Distinguish three responsibilities: the **policy owner** chooses a value, the **consumer** implements its runtime behavior, and the **host** supplies genuine local exceptions. A shared theme, for example, owns application color and font mappings; the application retains its controls and functional integrations. Do not move a shared policy into a consumer merely to shorten its import path.

Use `scopeEdits` when one semantic owner intentionally configures another. Apply cross-scope edits at the policy owner, addressed to the existing consumer scope, rather than introducing a parallel imported integration module or duplicating the same assignments in multiple scopes. The consumer retains responsibility for its functional configuration.

Reserve `dotfiles.*` options for durable, reusable policy inputs. Prefer native module options for ordinary implementation details. Use `scopeOptions` for typed policy owned by a scope and `dotfiles.*` for durable inputs shared across scopes. Runtime frontends consume or adapt those inputs rather than declaring a competing policy schema. Avoid modifying the scope machinery to accommodate a host-local exception.

Validate parent enablement, shared/host merges, and effective results on affected hosts. See the [generated scope reference](../configuration/scopes.md) for evaluated options.
