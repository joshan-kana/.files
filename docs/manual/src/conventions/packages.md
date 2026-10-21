# Packaging

**Convention:** Prefer stock nixpkgs and native module defaults. Register genuine custom builds, upstream pins, flake-provided packages, and compatibility overrides through `overlays/default.nix`. Consume them via `pkgs.<name>` in semantic modules.

## Package boundary

A package defines **what executable or artifact is built**. The semantic owner defines **how it is configured and run**.

For substantial custom builds, use `overlays/<package>/default.nix` to register the overlay and a colocated `package.nix` for the derivation. The entry point commonly calls `final.callPackage ./package.nix { };`. Follow the existing overlay registry instead of importing the builder directly from a service.

```nix
# overlays/example/default.nix
_: {
  nixpkgs.overlays = [
    (final: _: {
      example = final.callPackage ./package.nix { };
    })
  ];
}
```

Keep version constraints, hashes, and patch rationale with the package source. Prefer pinned metadata from the existing locked inputs when appropriate. For signed macOS applications, archive integrity alone does not prove the installed bundle can launch.

## Not every derivation needs an overlay

Small configuration-dependent wrappers created with `pkgs.writeShellApplication`, generated settings via `pkgs.formats`, systemd launch scripts, and other service-local glue normally belong with the semantic owner.

Do not override a native `package` option merely to repeat its default. Conversely, an explicit choice can remain necessary when upstream's default derivation differs. Compare actual outputs before simplifying.

Gate custom binaries to supported architectures. Avoid exporting an unusable package name on an unsupported OS.

## Checks

Compare custom package and host derivations for packaging-only relocations. Build non-stock artifacts on supported systems. Verify service commands still reference the same installed paths and run the full formatter and flake checks.
