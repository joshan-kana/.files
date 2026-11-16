# Packaging

Use the first suitable packaging source for the required functionality and supported platforms:

1. **nixpkgs:** Prefer the maintained stock derivation and native module package default.
2. **Upstream flake:** Use the publisher's working flake package when nixpkgs is unsuitable.
3. **Official binary release:** Package a reproducible, verified upstream artifact when neither earlier option suffices.
4. **Source build:** Maintain a derivation when the preceding choices cannot meet the requirement.

A source is unsuitable when it lacks required functionality, is stale, fails to build or run, or cannot support the target platform. Prefer the least invasive remedy. Revisit deviations when upstream support improves.

## Package ownership

Put independent package definitions and source pins under `overlays/<package>/default.nix`, registered in `overlays/default.nix`. Store downstream patch files in root `patches/<package>/` and reference them from the package definition. Keep an ordinary package's derivation with its overlay rather than adding a redundant file or registry. Extract reusable builders into `lib/` only when genuinely shared.

Consumers use `pkgs.<name>` and own service settings, application behavior, and platform enablement. Small launch wrappers and generated configuration need not become independent packages.

Reusable artifact builders handle installation and packaging; release discovery and update policy are selected separately according to the source. Keep provider-specific update behavior out of general package builders.

## nixpkgs compatibility exceptions

Prefer a narrow override of the existing nixpkgs derivation over replacing it. A stale release, missing capability, upstream regression, or build failure may justify an exception.

- For a broken nixpkgs revision, use a file-local, immutable `builtins.getFlake` reference to the latest known-good (or fixed) nixpkgs revision and select the target system's `legacyPackages`. Do not turn a temporary compatibility pin into a permanent flake input.
- If the stock derivation only needs a newer source or a small fix, override the relevant attributes or apply a patch.
- If nixpkgs cannot provide the required functionality, use the upstream flake, official binary, or source-build fallback in that order.

### Temporary compatibility overrides

A package's `overlays/<package>/default.nix` owns its durable definition and customizations. Place temporary compatibility overrides in a sibling `overlays/<package>/temporary.nix`, composed **after** the durable overlay in the same `nixpkgs.overlays` list. Where several independent fixes need separate removal, use separate sibling Nix files with descriptive names. Keep downstream patch contents in root `patches/<package>/`.

Each temporary override must set `passthru.autoUpdate = false` on every affected package, preserving other `passthru` attributes. Applying it last takes precedence over any `passthru.autoUpdate = true` in the durable package definition. For package-set extensions, set the policy on the affected derivation rather than on the extension list. Do not add a separate lifecycle registry or upstream-fix metadata.

A purely temporary package override can have a `default.nix` that only composes its sibling `temporary.nix`. Keep the entry in the central overlay registry until the whole override is no longer needed. Document the technical reason and removal condition beside the fix, without coupling it to a particular update run or issue. Preserve intentional customization independently of compatibility changes.

When the stock package or upstream source may have resolved the problem, remove only the temporary overlay and its import in an isolated change, then evaluate and build every affected platform and perform relevant runtime checks. Remove unreferenced downstream patches at the same time. The durable package's original `autoUpdate` setting applies again automatically, without a manual reset. If the package has no remaining customizations, remove its now-empty overlay registration and directory as well.

Do not preserve a fork or compatibility pin merely because it already exists.

## Update policy

Stock nixpkgs packages and patches to stock derivations follow the nixpkgs lock update. Packages sourced from flake inputs follow those locked inputs, without a separate source-version pin. Downstream dependency hashes are refreshed independently of source revisions when an override is necessary. Independently packaged source or binary releases use immutable versions and hashes, with standard updating where possible; resolve mutable release metadata during updates rather than evaluation.

A flake input follows its lockfile independently of `passthru.autoUpdate`. Do not confuse package update eligibility with whether an overlay is intentional or temporary. Declare `passthru.autoUpdate = true` for package-owned release or dependency hashes that are safe to refresh routinely, or `false` when they require explicit selection. Omit the metadata when there is no separately maintained package update. Set `passthru.autoUpdate = false` for packages with downstream patches; patch application and compatibility must be reviewed before updating them. Keep update policy with package metadata, not in host-specific lists or another version database.

Updates must fail without replacing a working lock or pin. Validate a proposed replacement on relevant architectures, including launch behavior or patch application where needed. Compatibility exceptions are removed only after the normal package is verified.
