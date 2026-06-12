# .files - my NixOS flake

This repo contains my entire NixOS system configuration managed as a flake.

## What's included
- Applications and packages
- System services
- Dotfiles (home-manager configs)
- Global system configs (e.g., `/etc`)
- Desktop environments (KDE Plasma, Hyprland)

## Flake profiles

This flake has three profiles for different environments:

- **nixos**: Full desktop config on x86_64 arch
- **nixos-arm-parallels**: Full desktop config on aarch64 arch (Parallels VM on macOS)
- **nixos-orbstack**: Minimal config for OrbStack (Linux containers on macOS, similar to WSL)
- **nixos-server**: server config

## Submodules

This repo uses a Git submodule for the shared infrastructure docs under
`docs/infrastructure-docs`.

When cloning this repo, either use:

```sh
git clone --recurse-submodules <repo-url>
```

or, after a normal clone, run:

```sh
git submodule update --init --recursive
```

When updating this repo later, refresh the submodule after pulling so the docs
links stay valid:

```sh
git pull
git submodule update --init --recursive
```

## Modular layout

The flake is organised around host entrypoints and coarse reusable modules:

- [`hosts/`](hosts/) contains real machines and host-specific topic files.
- [`modules/nixos/`](modules/nixos/) contains shared NixOS modules and typed
  `dotfiles.*` options.
- [`modules/home/`](modules/home/) contains shared Home Manager modules.

See [`docs/modular-nix-flake.md`](docs/modular-nix-flake.md) for the module
boundaries, option namespace, Home Manager integration, and validation commands.

## Quick commands

Shell aliases are defined in [`modules/home/cli.nix`](modules/home/cli.nix):

### System management
- `sysup` - Rebuild and switch to new system configuration
- `systest` - Test system configuration without switching
- `sysvm` - Build and run NixOS VM with current config
- `sysfu` - Preview flake updates with nvd diff
- `sysedit` - Edit configuration in VSCode

### Formatting
- `nix fmt` - Format all `.nix` files in this repo with treefmt
- `git config core.hooksPath .githooks` - Configure Git to run repo hooks from `.githooks/`

### Editor dev shells
- `nix develop .#vscode` - Nix language tooling (nixd + nixfmt + treefmt + lint tools) and optionally VS Code/VSCodium if available

VS Code config lives in `.vscode/` (recommended extensions, nixd config, and a couple snippets that end blocks with `};`).

Suggested launch commands (so `nixd`/`nixfmt` are on `PATH` for the extension):
- `nix develop .#vscode -c code .` (or `codium .` depending on what nixpkgs provides)

### Desktop environments
- `h` - Start Hyprland
- `HI` - Start Hyprland on Intel GPU
- `HN` - Start Hyprland on NVIDIA GPU
- `k` - Start KDE Plasma on Wayland

## Installation
Check Obsidian docs
