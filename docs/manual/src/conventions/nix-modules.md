# Nix modules

Prefer readable native NixOS, nix-darwin, and Home Manager definitions over custom wrappers that merely rename native options.

## Defaults and expressions

- Rely on native defaults when their behavior is suitable; verify effective values before removing explicit assignments.
- Use a local variable when a value is shared, derived, or conveys policy. Avoid `let` bindings that only rename a single expression.
- Derive repeated configurable values from one owner rather than copying constants across modules.
- Use comments to explain non-obvious constraints and rationale, not to restate assignments.
- Preserve the shared module's behavior when adding host-specific overrides.

## Scope and module boundaries

Share module-shaped native configuration between evaluators when their option paths and schemas agree. When they differ, share the underlying values and map them to each native interface. Keep the Home Manager evaluator boundary described in [semantic scopes](semantic-scopes.md).

Generate configuration for separate runtime processes from the owning Nix options. Keep ephemeral UI state and application-managed data outside the declarative option interface.

Distinguish enforced declarative policy from defaults for runtime-adjustable preferences. Where runtime adjustment is supported, a persisted user preference takes precedence over the configured default until reset; explicitly enforced policy takes precedence over both. Live service state remains with its owning service. Use native preference mechanisms where available rather than a competing persistence layer.

## Conditionals

Use the expression appropriate to what is conditional:

| Intent                                 | Expression          |
| -------------------------------------- | ------------------- |
| Include or omit attributes             | `lib.optionalAttrs` |
| Include or omit list elements          | `lib.optionals`     |
| Conditionally apply module definitions | `lib.mkIf`          |
| Select between values                  | `if … then … else`  |

Exclude unsupported option namespaces from the module structure before evaluation. Use `lib.mkIf` for conditional definitions of options that exist in the evaluator, rather than to hide unknown options.

## Precedence and checks

Use `lib.mkDefault` and `lib.mkForce` only with their actual module merge semantics in mind. Prefer a local override to changing shared defaults for one exceptional host.

See [validation](validation.md) for checks on effective configuration.
