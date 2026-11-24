# Packaging

Use the first suitable packaging source for the required functionality and supported platforms:

1. **nixpkgs:** Prefer the maintained stock derivation and native module package default.
2. **Upstream flake:** Use the publisher's working flake package when nixpkgs is unsuitable.
3. **Official binary release:** Package a reproducible, verified upstream artifact when neither earlier option suffices.
4. **Source build:** Maintain a derivation when the preceding choices cannot meet the requirement.

Choose a source that provides the required functionality and works on the target platform. Prefer the least invasive override of a suitable upstream package.

## Package ownership

Put independent package definitions and source pins under `overlays/<package>/default.nix`, registered in `overlays/default.nix`. Store downstream patch files in root `patches/<package>/` and reference them from the package definition. Keep an ordinary package's derivation with its overlay rather than adding a redundant file or registry. Extract reusable builders into `lib/` only when genuinely shared.

Keep overlays limited to package definitions and overrides. Register native service and Home Manager modules through host composition, with custom service implementations beside their owning capability. Consumers use `pkgs.<name>` and own service settings, application behavior, and platform enablement. Small launch wrappers and generated configuration need not become independent packages.

Reusable artifact builders handle installation and packaging; release discovery and update policy are selected separately according to the source. Keep provider-specific update behavior out of general package builders.

## nixpkgs compatibility exceptions

Prefer a narrow override of the existing nixpkgs derivation over replacing it. A stale release, missing capability, upstream regression, or build failure may justify an exception.

- For a broken nixpkgs revision, use a file-local, immutable `builtins.getFlake` reference to the latest known-good (or fixed) nixpkgs revision and select the target system's `legacyPackages`. Do not turn a temporary compatibility pin into a permanent flake input.
- If the stock derivation only needs a newer source or a small fix, override the relevant attributes or apply a patch.
- If nixpkgs cannot provide the required functionality, use the upstream flake, official binary, or source-build fallback in that order.

### Temporary compatibility overrides

Keep maintained downstream patches, package variants, customizations and their pins in the durable package definition. A temporary override is an interim measure with a defined removal condition, not simply an override of upstream code. Compose `overlays/<package>/temporary.nix` after the durable overlay in the same `nixpkgs.overlays` list. Independent temporary fixes may use separate, descriptively named sibling files.

Prefer `overrideAttrs` for derivation adjustments and use package-specific override mechanisms when needed. Preserve the package interfaces consumed by downstream modules.

Set `passthru.autoUpdate = false` on each temporary override of a package participating in the updater. A temporary layer applying a downstream patch must explicitly set it even when the durable definition already does. Merge with existing `passthru` metadata. Set the policy on the affected derivation, not the package-set extension. An unpatched stock-only build adjustment or generated environment without an independent update contract does not need update metadata.

A temporary-only overlay retains its registered `default.nix` entry point. Explain the reason for the workaround and its removal condition beside the fix.

Remove a temporary layer and its import once the normal package satisfies the requirement and passes affected build and runtime checks. Remove unused patch files and any empty overlay registration. The durable definition and its update policy remain intact.

## Update policy

Stock packages follow the nixpkgs lock; packages sourced from flake inputs follow their input locks. Independently maintained source and binary releases use immutable revisions or versions and hashes. Resolve mutable release metadata during updates rather than evaluation. Refresh downstream dependency hashes when required by the selected source.

Package update eligibility is defined by `passthru.autoUpdate`: `true` for routine updates, `false` for explicit selection, and absent for packages without an independent update contract or downstream patches. Patched packages must declare `false` regardless of the patch lifecycle. Flake lock updates are independent of this flag and still require compatibility review. When a package's maintained source is outside its entry point, point its update filename at the owning file. Keep update policy in package metadata.

Validate proposed revisions on the relevant architectures, including patch application and launch behavior where applicable. Keep the last verified lock or pin recoverable when an update fails.
