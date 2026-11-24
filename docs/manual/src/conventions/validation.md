# Validation

Validate the behavioral effect of a change, not only the source syntax. Choose checks appropriate to the affected scopes, platforms, and risks.

## Baseline

Every pull request must pass the formatter, whitespace check, native flake checks, and cross-system evaluation on its final revision. For local validation, run both flake commands with remote builders disabled:

```sh
nix fmt -- --ci
git diff --check
git diff --cached --check
nix flake check --option builders ''
nix flake check --no-build --all-systems --option builders ''
```

After applying automatic fixes, run the complete formatter/linter pipeline again in check mode and verify that it produces no changes. Audit file-to-formatter assignments when changing tooling: each supported source type needs coverage, and no file should have competing formatters. Confirm deliberate exclusions remain excluded.

For manual changes, build the assembled documentation source and rendered book, check links/navigation, and inspect representative output.

Cross-system evaluation must not require foreign-architecture builds. Perform additional platform-specific builds and runtime checks separately.

## Evidence by change type

- **Behavior-preserving refactor:** compare evaluated configurations and relevant system derivations before and after.
- **Package change:** evaluate consumers, build on relevant architectures, and test execution or patch behavior where necessary.
- **Service change:** inspect effective units, dependencies, credentials, ownership, network exposure, and startup behavior.
- **Desktop change:** validate actual rendering, focus, input, performance, and accessibility.
- **Security/network change:** verify listener bindings, firewall rules, authentication, and reachable paths.
- **Storage change:** verify data preservation, permissions, backup coverage, and recovery.

An unexpected derivation change warrants investigation. A matching derivation is useful evidence of preservation, but does not establish every runtime property.

## Tests and reporting

Test behavior by exercising the component or executable. Include deterministic, self-contained regression tests in the flake checks; keep tests requiring live services or hardware separate. For shared scope changes, check both enabled and disabled configurations and any dependent scopes. Exercise non-default values when changing shared policy or its consumers. Derive fleet-wide validation targets from the configuration outputs; use explicit host fixtures only for host-specific requirements. Use source assertions for stable structural invariants, rather than as substitutes for behavioral tests or subjective style checks.

Report which evaluations, builds, and live tests actually passed. A merged change, a successful build, and a successful deployment are distinct outcomes.
