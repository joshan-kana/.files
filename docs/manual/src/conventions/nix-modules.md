# Nix modules

Prefer readable native NixOS, nix-darwin, and Home Manager definitions over custom wrappers that merely rename native options.

## Defaults and expressions

- Rely on native defaults when their behavior is suitable; verify effective values before removing explicit assignments.
- Use a local variable when a value is shared, derived, or conveys policy. Avoid `let` bindings that only rename a single expression.
- Derive repeated configurable values from one owner rather than copying constants across modules.
- Keep comments for non-obvious constraints and rationale. Code that merely repeats the following assignment adds no value.
- Preserve the shared module's behavior when adding host-specific overrides.

## Conditionals

Use the expression appropriate to what is conditional:

| Intent                              | Expression          |
| ----------------------------------- | ------------------- |
| Include or omit attributes          | `lib.optionalAttrs` |
| Include or omit list elements       | `lib.optionals`     |
| Conditionally define module options | `lib.mkIf`          |
| Select between values               | `if … then … else`  |

Gate platform-specific native options before they enter an unsupported evaluator. Prefer a simple condition over elaborate merges that obscure intent.

## Precedence and checks

Use `lib.mkDefault` and `lib.mkForce` only with their actual module merge semantics in mind. Prefer a local override to changing shared defaults for one exceptional host.

Format with the repository toolchain, run relevant checks, and compare evaluated results when refactoring definitions that should preserve behavior.
