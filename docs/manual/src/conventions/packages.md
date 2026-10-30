# Packaging

**Convention:** Prefer upstream packaging, keep reproducible updates working wherever possible, and introduce only the smallest override needed for a real compatibility or packaging gap.

## Package source order

Use the first suitable source for the target platforms:

1. **Stock nixpkgs.** Prefer its maintained derivation and native NixOS or Home Manager package default.
2. **Upstream flake.** Prefer the publisher's working Nix package over maintaining an equivalent derivation; pin a maintained flake input where normal `nix flake update` should advance it.
3. **Official upstream binary release.** Package a reproducible, verified artifact when the publisher provides a better-supported binary than its source build.
4. **Build from source.** Maintain a derivation when none of the above works or required functionality is otherwise unavailable.

A higher-priority choice can be rejected when it is broken, too old for required functionality, or unsuitable for the target platform, signing model, or dependencies. Revisit the exception as upstream packages improve instead of maintaining a permanent fork.

## Ownership

Package construction, source pins, and package patches belong in `overlays/<package>/default.nix`, registered through `overlays/default.nix`. Define the package in that file rather than splitting an ordinary package into a redundant `package.nix`. Share genuinely reusable builders through `lib/`; do not add a second package registry.

Semantic modules consume the registered package as `pkgs.<name>` and own its configuration, service lifecycle, and platform enablement. Small service-local wrappers, generated settings, and launch scripts need not become overlays. Gate packages to systems that can actually use them.

## Temporary nixpkgs gaps

Use a minimal overlay when nixpkgs cannot yet supply the needed package, version, behavior, or platform support. This includes stale releases, regressions, missing features, and build failures. Prefer repairing or updating its existing derivation over replacing the package unnecessarily.

- **Regression:** If an earlier nixpkgs revision worked, select the latest known-good package from that revision through a file-local, immutable `builtins.getFlake` reference and `legacyPackages` for the target system. A newer nixpkgs revision containing a fix can be selected the same way. Do not add a permanent top-level input for such an exception.
- **Stale or incomplete package:** If nixpkgs does not yet contain the needed release or feature, first consider a small source/version override of its derivation. Otherwise follow the upstream flake, official binary, and source-build order. Keep independently maintained sources updateable where safe rather than freezing a version solely because the package is custom.
- **Patch:** Prefer patching the current nixpkgs derivation directly. Pin an alternate nixpkgs revision only when necessary for compatibility. Keep the rationale and relevant upstream fix or issue beside the overlay; do not add version suffixes without a technical need.

**A compatibility overlay is disposable.** When nixpkgs supplies a suitable version, build, feature, or upstream fix, validate that stock package and remove the entire override. Neither a version bump nor a fallback pin should become a permanent fork merely through inertia.

## Update lifecycle

- **Stock nixpkgs and patches on stock derivations** follow the repository's `flake.lock` update and normal build checks. They do not need an independent release updater.
- **Flake-provided packages** follow their locked flake input when independently maintained as an input. Explicit, immutable `builtins.getFlake` compatibility pins do not silently advance during `nix flake update`.
- **Independently packaged binaries and source builds** pin immutable versions and hashes with the package. Use `nix-update` by default; add `passthru.updateScript`, `passthru.updateUrl`, or `passthru.updateMode` only when the publisher's release process requires it. Resolve mutable release pointers during updates, not evaluation.
- Set `passthru.autoUpdate = true` when the independent package can safely join routine `system-update --all` updates. Set it to `false` for a manually reviewed pin; it remains selectable with `system-update --package NAME [--system SYSTEM]`. Without this metadata, a derivation is not independently registered for package updates. These flags do not themselves freeze or advance the nixpkgs revision.

Use `nix run .#system-update` for the interactive update workflow; the scheduled `--all` path uses the same logic. Do not add a duplicate version/hash database or a hard-coded per-host update list. Preserving a known-good fallback takes precedence over automatically applying an unverified update.

## Verification

Evaluate supported systems, build changed packages on matching architectures, and test launch or service behavior when evaluation cannot establish compatibility. For every temporary deviation, test whether current nixpkgs now meets the original requirement, verify patch application and functionality where relevant, and identify when the overlay can be deleted. An update failure must preserve the working pin and produce a reviewable change. Run repository format, flake, and relevant documentation checks before delivery.
