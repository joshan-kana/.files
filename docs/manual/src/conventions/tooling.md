# Tooling

Use the repository-provided development environment, formatter, tests, and commands. Prefer reproducible dependencies to globally installed tools.

## Toolchain

Use `nix develop` for repository work and Nix-provided tools for missing temporary dependencies. Keep formatter and linter definitions in the shared tooling configuration. Add language support through the same toolchain rather than introducing a separate ad hoc path for each feature.

Formatting, linting, type checks, and runtime tests verify different properties; one cannot stand in for the others.

## Formatting and linting

Use one authoritative formatter for each file type. Linters may inspect the same files and apply compatible automatic fixes, but their rules must not undo or compete with the formatter's output. Preserve stable formatting across repeated runs.

Prefer native language extensions and tool defaults for source discovery. When a runtime requires an extensionless configuration filename, keep the source identifiable to language tools and install it under the required destination name. Do not maintain per-file allowlists for ordinary source files.

Apply coherent, actionable lint rules rather than enabling every optional rule indiscriminately. Python public modules, classes, methods, and functions should follow PEP 257 docstring conventions and naming rules. Keep formatter-owned choices, such as Python line wrapping, out of competing lint enforcement.

Use narrow, explained exceptions for external API naming contracts, intentionally generated content, and rules that conflict with an authoritative formatter or with repository behavior. Preserve accepted exceptions when extending lint coverage; avoid disabling an entire rule family to accommodate a single legitimate case.

## Commands and scripts

Physical script placement follows [file ownership](repository-structure.md#file-ownership-and-placement). Source files are located by semantic ownership; Nix wrappers, flake outputs, and runtime units reference or package them without duplicating the implementation. In particular, a script used by only one feature does not become a repository-wide command simply because that feature is composed through `flake.nix`.

- Prefer small, readable, directly runnable commands over opaque wrappers.
- Use native module options for shell settings when possible.
- Keep feature-specific logic with its owner; use root `scripts/` for repository-wide commands and helpers that genuinely cross owners.
- Declare executable runtime dependencies and interpreter requirements rather than depending on an interactive user's shell or `$PATH`.
- Prefer supported native tools and protocols before writing glue. Keep operations safe to repeat; separate dry-run/reporting paths from destructive actions where appropriate.
- Preserve observable CLI behavior and help text when refactoring command implementation.

Test commands under the environments in which they will run. Avoid introducing another layer of tooling unless it removes real repetition or complexity.
