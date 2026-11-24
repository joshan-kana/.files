# Validation

Validate the behavioral effect of a change, not only the source syntax. Choose checks appropriate to the affected scopes, platforms, and risks.

## Baseline

Run `nix fmt -- --ci`, `git diff --check`, and the configured flake checks. Review skipped systems separately.

After applying automatic fixes, run the complete formatter/linter pipeline again in check mode and verify that it produces no changes. Audit file-to-formatter assignments when changing tooling: each supported source type needs coverage, and no file should have competing formatters. Confirm deliberate exclusions remain excluded.

For manual changes, build the assembled documentation source and rendered book, check links/navigation, and inspect representative output.

Run native `nix flake check` and cross-system `nix flake check --no-build --all-systems` without requiring remote builders. Cross-system evaluation must not require foreign-architecture builds. Perform platform-specific builds and runtime checks separately.

## Evidence by change type

- **Behavior-preserving refactor:** compare evaluated configurations and relevant system derivations before and after.
- **Package change:** evaluate consumers, build on relevant architectures, and test execution or patch behavior where necessary.
- **Service change:** inspect effective units, dependencies, credentials, ownership, network exposure, and startup behavior.
- **Desktop change:** validate actual rendering, focus, input, performance, and accessibility.
- **Security/network change:** verify listener bindings, firewall rules, authentication, and reachable paths.
- **Storage change:** verify data preservation, permissions, backup coverage, and recovery.

An unexpected derivation change warrants investigation. A matching derivation is useful evidence of preservation, but does not establish every runtime property.

## Tests and reporting

Test behavior by exercising the component or executable. Use source assertions for stable structural invariants, rather than as substitutes for behavioral tests or subjective style checks.

Report which evaluations, builds, and live tests actually passed. A merged change, a successful build, and a successful deployment are distinct outcomes.
