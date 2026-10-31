# Packaging

Use the first suitable packaging source for the required functionality and supported platforms:

1. **nixpkgs:** Prefer the maintained stock derivation and native module package default.
2. **Upstream flake:** Use the publisher's working flake package when nixpkgs is unsuitable.
3. **Official binary release:** Package a reproducible, verified upstream artifact when neither earlier option suffices.
4. **Source build:** Maintain a derivation when the preceding choices cannot meet the requirement.

A source is unsuitable when it lacks required functionality, is stale, fails to build or run, or cannot support the target platform. Prefer the least invasive remedy. Revisit deviations when upstream support improves.

## Package ownership

Put independent package definitions, patches, and source pins under `overlays/<package>/default.nix`, registered in `overlays/default.nix`. Keep an ordinary package's derivation with its overlay rather than adding a redundant file or registry. Extract reusable builders into `lib/` only when genuinely shared.

Consumers use `pkgs.<name>` and own service settings, application behavior, and platform enablement. Small launch wrappers and generated configuration need not become independent packages.

## nixpkgs compatibility exceptions

Prefer a narrow override of the existing nixpkgs derivation over replacing it. A stale release, missing capability, upstream regression, or build failure may justify an exception.

- For a broken nixpkgs revision, use a file-local, immutable `builtins.getFlake` reference to the latest known-good (or fixed) nixpkgs revision and select the target system's `legacyPackages`. Do not turn a temporary compatibility pin into a permanent flake input.
- If the stock derivation only needs a newer source or a small fix, override the relevant attributes or apply a patch.
- If nixpkgs cannot provide the required functionality, use the upstream flake, official binary, or source-build fallback in that order.
- Document the technical reason and upstream resolution condition beside an exception. Remove the overlay once the stock package passes the required checks.

Do not preserve a fork or compatibility pin merely because it already exists.

## Update policy

Stock nixpkgs packages and patches to stock derivations follow the nixpkgs lock update. Independently maintained flake packages follow their locked inputs. Independently packaged source or binary releases use immutable versions and hashes, with standard updating where possible; resolve mutable release metadata during updates rather than evaluation.

Declare `passthru.autoUpdate = true` for independently updateable packages that are safe to update routinely, or `false` when updates require explicit selection. Omit the metadata when independent package updates do not apply. Keep update policy with package metadata, not in host-specific lists or another version database.

Updates must fail without replacing a working lock or pin. Validate a proposed replacement on relevant architectures, including launch behavior or patch application where needed. Compatibility exceptions are removed only after the normal package is verified.
