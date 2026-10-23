# Tooling

**Convention:** Prefer the development environment and repository-provided commands, keep scripts readable and portable to their intended hosts, and apply consistent formatter/linter support when introducing a language.

## Development environment

The repository's `nix develop -c $SHELL` provides the intended toolchain. Prefer Nix-provided dependencies, `nix shell` for necessary temporary tools, and packages already defined by the flake rather than global, untracked package installations.

`nix fmt` is the formatting entry point. The flake's Treefmt configuration owns the language formatters, linters, ordering, and exclusions. Language support added to the repository should use the shared, language-agnostic Treefmt configuration rather than a special-case script under one app.

Run `nix fmt -- --ci` to check without applying edits. The repo-quality pre-commit hook checks formatting and linting, while the staged-whitespace hook runs `git diff --cached --check`.

## Scripts, aliases, and small helpers

- Prefer ordinary, copyable commands and small scripts over opaque wrappers or encoding tricks.
- Prefer native `environment.shellAliases` and Home Manager options for shell configuration when appropriate.
- Put feature-specific operational logic with the feature when that is clearer than a generic script directory; shared repository commands can live in `scripts/`.
- Use package-provided executables and explicit runtime dependencies for executable scripts where practical.
- Keep scripts idempotent where re-running is expected. Separate a reporting/check mode from a destructive fix mode when that distinction matters.
- Prefer the supported execution environment of each host over assumptions about a local user shell.

## Review

Formatting success does not prove shell portability, editor correctness, or service behavior. Validate scripts in their relevant runtime, evaluate consumers, and preserve exact help/usage semantics when refactoring a tool.

Do not introduce a new convenience abstraction unless it reduces complexity for the actual users of the repository.
