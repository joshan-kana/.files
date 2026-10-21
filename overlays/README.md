# Packaging in `.files`

The [declarative configuration architecture](https://github.com/joshan-kana/infrastructure-docs/blob/main/docs/DECLARATIVE_CONFIGURATION_ARCHITECTURE.md) defines semantic ownership. For package implementations, use this convention:

- **Use stock `pkgs` first.** Do not create an overlay or set `programs.*.package` merely to restate a native default.
- **Register non-stock software through `overlays/default.nix`.** External flake packages, upstream pins, compatibility overrides, and custom derivations belong under `overlays/<package>/`. Give each package one `default.nix` that contributes to `nixpkgs.overlays`. Put a substantial derivation in a colocated `package.nix`, exposed with `final.callPackage ./package.nix { ... };`.
- **Keep a stable `pkgs.<name>` interface.** Semantic modules and hosts consume packages from `pkgs`, not by importing derivation files or directly selecting `inputs.*.packages`/`legacyPackages`.
- **Keep policy where it is used.** Runtime service settings, credentials, unit definitions, generated configuration, and small configuration-dependent launch/wrapper scripts stay in their owning semantic module. A generated file or service-specific helper does not need a global overlay entry just because Nix creates a derivation for it.
- **Gate platform-specific packages.** Use `lib.optionalAttrs` in overlay definitions when software is not available on every configured OS. Keep version pins and hashes next to the package definition, using locked inputs and fixed-output sources where appropriate.

For example, `openai-tunnel-client/` owns the pinned binary, while `serverApps.agentTools.chatgptShellAccess` owns its tunnel credentials, systemd unit, and start command. Keep a native module's explicit package selection when removing it changes the effective derivation.

Before submitting a package change, run the repository formatter and `nix flake check`, compare relevant host and package derivations against the base revision, and build non-stock packages on a supported system when practical.
