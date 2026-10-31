# Tooling

Use the repository-provided development environment, formatter, tests, and commands. Prefer reproducible dependencies to globally installed tools.

## Toolchain

Use `nix develop` for repository work and Nix-provided tools for missing temporary dependencies. Keep formatter and linter definitions in the shared tooling configuration. Add language support through the same toolchain rather than introducing a separate ad hoc path for each feature.

Formatting, linting, type checks, and runtime tests verify different properties; one cannot stand in for the others.

## Commands and scripts

- Prefer small, readable, directly runnable commands over opaque wrappers.
- Use native module options for shell settings when possible.
- Keep feature-specific logic with its owner; use `scripts/` for broadly reusable repository commands.
- Declare executable runtime dependencies rather than depending on an interactive user's shell.
- Design repeatable operations to be safe when run again. Separate dry-run/reporting paths from destructive actions where appropriate.
- Preserve observable CLI behavior and help text when refactoring command implementation.

Test commands under the environments in which they will run. Avoid introducing another layer of tooling unless it removes real repetition or complexity.
