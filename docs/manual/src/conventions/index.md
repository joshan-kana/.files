# Conventions

The `.files` manual is the contributor-facing reference for repository conventions. These conventions apply to contributors regardless of editor, tool, platform, or workflow. All topics are peers; their placement in the manual implies no priority ranking.

Prefer native interfaces, semantic ownership, and small, comprehensible changes. The rules describe current repository practice, not generic Nix ideology.

## Find a convention

- [Repository structure](repository-structure.md): placement, registries, and imports.
- [Semantic scopes](semantic-scopes.md): feature ownership and Home Manager boundaries.
- [Nix modules](nix-modules.md): module shape, conditionals, defaults, and overrides.
- [Platforms](platforms.md): Linux, Darwin, and architecture-specific behavior.
- [Packaging](packages.md): stock packages, overlays, build expressions, and consumers.
- [Services](services.md): application lifecycle, users, dependencies, and permissions.
- [Networking and security](networking-and-security.md): exposure boundaries, secrets, access.
- [State and recovery](state-and-recovery.md): storage, identities, and backup coverage.
- [Desktop and appearance](desktop-and-appearance.md): application, theme, and compositor ownership.
- [Tooling](tooling.md): scripts, formatters, language support, and checks.
- [Validation](validation.md): evaluated, built, and live verification.
- [Git and delivery](git-and-delivery.md): branches, PRs, issue tracking, review, and deployment.
- [Documentation](documentation.md): this manual, generated pages, and durable policy.

## Applying a convention

1. Read the current implementation and find its semantic owner.
2. Follow applicable conventions, including any explicit exception appropriate to the task.
3. Keep mechanical refactors behavior-preserving and verify that claim through evaluated output.
4. Update a convention page when a decision materially changes the convention, not for every implementation PR.

Enforcement may be automated, evaluated, or reviewed. A new source-code linter or abstraction is not justified solely to enforce a subjective preference.

## Authority and related material

Current code and evaluated behavior establish what is implemented. The [generated option reference](../configuration/options.md) and [scope reference](../configuration/scopes.md) describe evaluated interfaces. This section documents `.files` contribution conventions. Cross-project decisions and operating policy belong to [Declarative Configuration Architecture](https://github.com/joshan-kana/infrastructure-docs/blob/main/docs/DECLARATIVE_CONFIGURATION_ARCHITECTURE.md), [Operating Style](https://github.com/joshan-kana/infrastructure-docs/blob/main/docs/OPERATING_STYLE.md), and [GitHub Project Workflow](https://github.com/joshan-kana/infrastructure-docs/blob/main/docs/GITHUB_PROJECT_WORKFLOW.md).

Historical documentation and previous PRs are evidence, not substitutes for current code. Surface contradictions instead of silently inventing precedence. Avoid copying implementation state and operational runbooks into policy pages.
