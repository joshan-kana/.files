# Modular Nix Flake Architecture

This repository uses plain modular Nix. The flake stays explicit and each host
imports a small number of coarse modules, instead of adopting Snowfall Lib,
flake-parts, or one-file-per-app fragmentation.

## Layout

- `hosts/` contains real machines and host-specific topic files.
- `modules/` contains reusable NixOS and Home Manager building blocks.
- `modules/nixos/options/common.nix` defines typed `dotfiles.*` options shared by
  all NixOS hosts.
- `modules/nixos/options/server.nix` defines server-only options and is imported
  only by `hosts/nixos-server`.

Host entrypoints are the source of truth:

- `hosts/nixos/default.nix` is the x86 Linux desktop.
- `hosts/nixos-arm-parallels/default.nix` is the aarch64 desktop VM.
- `hosts/nixos-orbstack/default.nix` is the OrbStack container profile.
- `hosts/nixos-server/default.nix` is the Raspberry Pi server.

## Options And Derived Values

Common values live under `dotfiles.*`:

- `dotfiles.profile.name`
- `dotfiles.users.primary.name`
- `dotfiles.users.primary.fullName`
- `dotfiles.users.primary.email`
- `dotfiles.users.primary.homeRoot`
- `dotfiles.paths.repoName`
- `dotfiles.rebuild.flags`
- `dotfiles.services.ollama.url`
- `dotfiles.features.cli.enable`
- `dotfiles.features.desktop.enable`
- `dotfiles.cli.disabledPrograms`
- `dotfiles.cli.disabledAliases`

Modules derive paths from those source values. For example, the primary home is
`${homeRoot}/${name}` and the repo path is `${primaryHome}/${repoName}`. This
keeps aliases, environment variables, and `nh` pointed at the same location.

## Home Manager

Home Manager is integrated as a NixOS module. Home modules read host settings
through `osConfig.dotfiles`, which avoids passing repeated values through
`specialArgs`.

The shared Home Manager modules are intentionally coarse:

- `modules/home/base.nix` sets identity and Home Manager basics.
- `modules/home/cli.nix` contains terminal, shell, Git, editor, and TUI tools.
- `modules/home/desktop-linux.nix` contains GUI desktop user configuration.
- `modules/home/x86-desktop.nix` contains x86 desktop-only user configuration.

Orbstack and the server import only the base and CLI modules.

## NixOS Modules

The shared NixOS modules are also coarse:

- `modules/nixos/base.nix` contains common Nix, user, locale, shell, package,
  and environment configuration.
- `modules/nixos/desktop-linux.nix` contains Linux desktop system configuration,
  including desktop services, fonts, virtualisation, sound, packages, Stylix,
  Hyprland, and Plasma.

Server implementation stays under `hosts/nixos-server/` because it currently
belongs to one concrete machine. The hosted container stack remains grouped in
`hosts/nixos-server/apps.nix`.

## Editor Support

`.vscode/settings.json` configures `nixd` to expose NixOS options and integrated
Home Manager options from this flake. This provides completion for the custom
`dotfiles.*` option namespace.

## Validation

Useful checks after changing the module graph:

```sh
nix fmt
git diff --check
nix flake show
nix eval .#nixosConfigurations.nixos.config.system.build.toplevel.drvPath
nix eval .#nixosConfigurations.nixos-arm-parallels.config.system.build.toplevel.drvPath
nix eval .#nixosConfigurations.nixos-orbstack.config.system.build.toplevel.drvPath
nix eval .#nixosConfigurations.nixos-server.config.system.build.toplevel.drvPath
```
