# Conventions

Contributions follow semantic ownership, native interfaces, and the smallest change that satisfies the requirement. Exceptions need a concrete technical reason and must remain local to the affected scope or platform.

## Topics

- [Repository structure](repository-structure.md)
- [Semantic scopes](semantic-scopes.md)
- [Nix modules](nix-modules.md)
- [Platforms](platforms.md)
- [Packaging](packages.md)
- [Services](services.md)
- [Networking and security](networking-and-security.md)
- [State and recovery](state-and-recovery.md)
- [Desktop and appearance](desktop-and-appearance.md)
- [Tooling](tooling.md)
- [Validation](validation.md)
- [Git and delivery](git-and-delivery.md)
- [Documentation](documentation.md)

## Applying the rules

Identify the semantic owner and examine its shared and host-local definitions before editing. Preserve existing behavior when restructuring code, and verify the effective configuration rather than assuming equivalent-looking Nix expressions are interchangeable.

A routine implementation that follows an established convention does not require a convention update. Change these pages only when an enduring rule or ownership boundary changes.

Cross-project architecture and operating policy belong to the [infrastructure handbook](https://github.com/joshan-kana/infrastructure-docs). Evaluated host options and scopes belong to the [generated reference](../configuration/options.md) and [scope reference](../configuration/scopes.md). Keep those sources distinct.
