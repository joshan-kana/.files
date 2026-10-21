# Validation

**Convention:** Validate the *semantic effect* of a change, not merely its syntax. Pick checks relevant to the changed behavior and distinguish evaluation, build success, and live deployment.

## Normal checks

```sh
nix fmt -- --ci
git diff --check
nix flake check
```

These verify repository formatting and linting, whitespace, Nix evaluation, and the flake's configured tests. Some checks are architecture-specific; read reported omissions instead of claiming that all hosts were built.

For a docs PR, build both `.#docs-source` and the rendered `.#docs` and inspect generated navigation, links, and content.

## Regressions and parity

- **Mechanical refactor:** compare the relevant `config.system.build.toplevel.drvPath` on all affected hosts before and after. Exact matches are strong evidence of behavior preservation.
- **Package relocation:** compare the package derivation and its consuming service or host derivation. Build non-stock packages on a supported target.
- **Service integration:** inspect evaluated service commands, secrets delivery, dependencies, and network settings; perform runtime smoke tests when possible.
- **Desktop behavior:** verify rendered UI, keyboard focus, input latency, and frame behavior on appropriate clients where evaluation cannot prove the result.
- **Network and security:** confirm the actual interfaces, access paths, and firewall rules on the target host.
- **Storage/recovery:** verify data preservation, permissions, backup coverage, and realistic restoration rather than relying solely on Nix assertions.

Do not silently explain away a changed derivation as harmless without investigating what changed. Conversely, avoid rebuilding the entire fleet for a docs-only source edit when the generated docs check already verifies the change.

## Test design

Prefer focused evaluated assertions for stable invariants. The [server-app standards test](https://github.com/joshan-kana/.files/blob/main/tests/server-app-standards.nix) is intentionally narrow. Subjective conventions are best reviewed rather than encoded into a sprawling source-code linter.

Report exactly what was run and which supported systems were evaluated, built, or deployed. A merged PR and a successful live deployment are separate states.
