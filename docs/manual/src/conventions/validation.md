# Validation

Validate the behavioral effect of a change, not only the source syntax. Choose checks appropriate to the affected scopes, platforms, and risks.

## Baseline

Run the repository's formatter/linter check, whitespace check, and configured flake checks. Review unsupported or skipped systems rather than treating one platform's result as fleet-wide verification.

For manual changes, build the assembled documentation source and rendered book, check links/navigation, and inspect representative output.

## Evidence by change type

- **Behavior-preserving refactor:** compare evaluated configurations and relevant system derivations before and after.
- **Package change:** evaluate consumers, build on relevant architectures, and test execution or patch behavior where necessary.
- **Service change:** inspect effective units, dependencies, credentials, ownership, network exposure, and startup behavior.
- **Desktop change:** validate actual rendering, focus, input, performance, and accessibility.
- **Security/network change:** verify listener bindings, firewall rules, authentication, and reachable paths.
- **Storage change:** verify data preservation, permissions, backup coverage, and recovery.

An unexpected derivation change warrants investigation. A matching derivation is useful evidence of preservation, but does not establish every runtime property.

## Tests and reporting

Prefer focused assertions for stable invariants and real runtime verification for behavior evaluation cannot prove. Do not encode subjective style preferences in a large, brittle source linter.

Report which evaluations, builds, and live tests actually passed. A merged change, a successful build, and a successful deployment are distinct outcomes.
