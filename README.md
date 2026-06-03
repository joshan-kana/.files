# .files - my *personalised* NixOS config

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

## Profile-specific variables

Each profile defines centralized variables in [`flake.nix`](flake.nix):
- `dotfilesPath`: Location of this repository
- `profileName`: Profile identifier for the flake
- `ollamaUrl`: Ollama API endpoint URL
- `nixosRebuildFlags`: Build flags passed to `nixos-rebuild` (e.g., `--impure`)

These are exposed as environment variables via the profile configuration files ([`profile_nixos.nix`](profile_nixos.nix), etc.).

## Quick commands

Shell aliases are defined in [`home.nix`](home.nix):

### System management
- `sysup` - Rebuild and switch to new system configuration
- `systest` - Test system configuration without switching
- `sysvm` - Build and run NixOS VM with current config
- `sysfu` - Preview flake updates with nvd diff
- `sysedit` - Edit configuration in VSCode

### Formatting
- `nix fmt` - Format Nix files passed to it (uses the flake `formatter`, currently `nixfmt` from nixpkgs)
- `nix run .#fmt` - Same as above (handy for CI / muscle memory)
- `nix run .#install-git-hooks` - Configure Git to run repo hooks from `.githooks/`

### Editor dev shells
- `nix develop .#vscode` - Nix language tooling (nixd + nixfmt + lint tools) and optionally VS Code/VSCodium if available
- `nix develop .#neovim` - Same tooling plus Neovim

VS Code config lives in `.vscode/` (recommended extensions, nixd config, and a couple snippets that end blocks with `};`).

Suggested launch commands (so `nixd`/`nixfmt` are on `PATH` for the extension):
- `nix develop .#vscode -c code .` (or `codium .` depending on what nixpkgs provides)
- `nix develop .#neovim -c nvim .`

### Desktop environments
- `h` - Start Hyprland
- `HI` - Start Hyprland on Intel GPU
- `HN` - Start Hyprland on NVIDIA GPU
- `k` - Start KDE Plasma on Wayland

## Installation
Check Obsidian docs
