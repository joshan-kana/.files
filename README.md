# .files

This repo contains my NixOS system and home configuration, managed as a flake.

## What's included

- NixOS host definitions
- Shared system modules
- Shared home configuration modules
- Desktop environments: KDE Plasma and Hyprland
- Server services, containers, app data, image building, and backups
- Editor settings for working on the flake

## Hosts

The flake exposes these NixOS configurations:

| Host | Purpose | Entry point |
| --- | --- | --- |
| `nixos` | x86_64 Linux desktop | `hosts/nixos/default.nix` |
| `nixos-arm-parallels` | aarch64 Linux desktop VM | `hosts/nixos-arm-parallels/default.nix` |
| `nixos-orbstack` | OrbStack Linux container | `hosts/nixos-orbstack/default.nix` |
| `nixos-server` | Raspberry Pi server | `hosts/nixos-server/default.nix` |

Host entrypoints are the source of truth for what each machine imports. Start
there when you want to know what applies to a machine.

## Layout

The flake uses plain modular Nix. It does not use Snowfall Lib or flake-parts.
Keep modules coarse and topic-based; avoid creating one file per small app unless
that app grows enough configuration to deserve its own module.

```text
hosts/              Real machines and host-specific topic files
modules/nixos/      Reusable NixOS modules
modules/home/       Reusable home configuration modules
overlays/           Package overlays
desktop/            Desktop-specific Plasma, Hyprland, and Eww files
scripts/            Helper scripts used by aliases and workflows
```

Use this rule when adding code:

- Put machine-specific behavior in `hosts/<host>/`.
- Put reused system behavior in `modules/nixos/`.
- Put reused user/home behavior in `modules/home/`.
- Keep server-only apps under `hosts/nixos-server/` until another server needs
  the same code.

## Common Options

Shared host values live under `dotfiles.*`, defined in
`modules/nixos/options/common.nix`.

Common options include:

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

Server-only options live in `hosts/nixos-server/options.nix` and are imported
only by `hosts/nixos-server/default.nix`.

Set host values in the host entrypoint. For example:

```nix
dotfiles = {
  profile.name = "nixos";
  users.primary.homeRoot = "/home";
  paths.repoName = ".files";
  services.ollama.url = "http://localhost:11434/v1";
};
```

Modules derive paths from those values, so changing the user, home root, or repo
name in one place updates aliases and environment variables together.

## Adding Programs

Choose the file based on where the program should run.

| Where it should apply | Put it here |
| --- | --- |
| Every host with CLI enabled | `modules/home/cli.nix` |
| Every desktop user session | `modules/home/desktop-linux.nix` |
| Every desktop system | `modules/nixos/desktop-linux.nix` |
| Every NixOS host | `modules/nixos/base.nix` |
| x86 desktop only | `hosts/nixos/x86.nix` for system config, `modules/home/x86-desktop.nix` for home config |
| Parallels desktop only | `hosts/nixos-arm-parallels/` |
| OrbStack only | `hosts/nixos-orbstack/` |
| Server only | `hosts/nixos-server/` |

Home programs usually use `programs.<name>` or `services.<name>` in a
`modules/home/*.nix` file. System packages, drivers, ports, systemd services,
virtualisation, and hardware settings usually belong in `modules/nixos/*.nix` or
`hosts/<host>/*.nix`.

Examples:

```nix
# modules/home/cli.nix
programs.jq.enable = enabled "jq";
```

```nix
# modules/nixos/desktop-linux.nix
environment.systemPackages = with pkgs; [
  obsidian
  pavucontrol
];
```

```nix
# hosts/nixos/x86.nix
environment.systemPackages = with pkgs; [
  brave
  spotify
];
```

## Disabling Shared CLI Items Per Host

`modules/home/cli.nix` uses the host option
`dotfiles.cli.disabledPrograms`.

Add a shared CLI program like this:

```nix
programs.ripgrep.enable = enabled "ripgrep";
```

Disable it for one host in that host's `default.nix`:

```nix
dotfiles.cli.disabledPrograms = [ "ripgrep" ];
```

Shell aliases in `modules/home/cli.nix` can be disabled the same way with
`dotfiles.cli.disabledAliases`:

```nix
dotfiles.cli.disabledAliases = [ "sysvm" ];
```

## Editing Existing Program Configuration

Use the current location of the program:

- Shell, Git, terminal tools, aliases, Neovim, tmux, zellij, yazi, and other CLI
  tools: `modules/home/cli.nix`
- Waybar, Wofi, Rofi, Tofi, Kitty, Alacritty, Firefox, Floorp, Dunst, Avizo,
  EasyEffects, GTK, and desktop home services: `modules/home/desktop-linux.nix`
- Desktop system services, fonts, Stylix, PipeWire, Docker, libvirt, desktop
  packages, firewall ports, boot, SSH, and VPN modules:
  `modules/nixos/desktop-linux.nix`
- Plasma home config: `desktop/plasma/plasma-hm.nix`
- Plasma NixOS config: `desktop/plasma/plasma.nix`
- Hyprland home config: `desktop/hyprland/hyprland.nix`
- Hyprland NixOS config: `desktop/hyprland/hyprland-nixos.nix`
- Server containers and hosted stack: `hosts/nixos-server/apps.nix`
- Server networking: `hosts/nixos-server/networking.nix`
- Server image build: `hosts/nixos-server/image.nix`
- Host hardware: `hosts/<host>/hardware.nix`

If a program is used by only one host, keep it under that host. Promote it into
`modules/` only when another host needs the same behavior.

## Programs With System And Home Config

Some tools have both a NixOS side and a home side. Treat those as two halves of
one feature:

- NixOS side: install system packages, enable system services, open firewall
  ports, configure drivers, desktop sessions, PAM, udev, Docker, PipeWire, and
  other machine-level behavior.
- Home side: configure dotfiles, user services, shell integration, themes,
  keybindings, browser profiles, editor settings, and per-user program options.

Keep the two halves in the layer they belong to. Import both halves only on hosts
that need the feature.

Current examples:

- Hyprland system config: `desktop/hyprland/hyprland-nixos.nix`
- Hyprland home config: `desktop/hyprland/hyprland.nix`
- Plasma system config: `desktop/plasma/plasma.nix`
- Plasma home config: `desktop/plasma/plasma-hm.nix`
- Desktop system baseline: `modules/nixos/desktop-linux.nix`
- Desktop home baseline: `modules/home/desktop-linux.nix`

For a new reusable feature with both halves, use matching modules:

```text
modules/nixos/my-feature.nix
modules/home/my-feature.nix
```

Import the system half from a host entrypoint:

```nix
# hosts/nixos/default.nix
imports = [
  ../../modules/nixos/my-feature.nix
];
```

Import the home half from that host's `default.nix`, next to the system half:

```nix
# hosts/nixos/default.nix
home-manager.users.${config.dotfiles.users.primary.name}.imports = [
  ../../modules/home/my-feature.nix
];
```

If the feature should be toggled as a unit, add an option in
`modules/nixos/options/common.nix`:

```nix
dotfiles.features.myFeature.enable = lib.mkEnableOption "my feature";
```

### Themes

Stylix is enabled for every NixOS configuration through `modules/nixos/theme.nix`.

The theme is intentionally shared across all hosts. Do not add per-host theme
overrides unless the repo policy changes.

The shared theme matches the old main-branch Stylix configuration: Framer from
`pkgs.base16-schemes`, `wallpaper.png`, Monaspace Neon, Noto Color Emoji, dark
polarity, and the GoogleDot-Black cursor.

Shared NixOS and Home Manager theme defaults live in `modules/nixos/theme.nix`.
Desktop app-specific target settings stay in `modules/home/desktop-linux.nix`
or the relevant `desktop/*` module.

Then guard both halves with the same option:

```nix
# modules/nixos/my-feature.nix
{ config, lib, ... }:

lib.mkIf config.dotfiles.features.myFeature.enable {
  services.my-feature.enable = true;
}
```

```nix
# modules/home/my-feature.nix
{ lib, osConfig, ... }:

lib.mkIf osConfig.dotfiles.features.myFeature.enable {
  programs.my-feature.enable = true;
}
```

Enable it per host:

```nix
# hosts/nixos/default.nix
dotfiles.features.myFeature.enable = true;
```

For one-host features, skip the reusable module until another host needs it.
Place host-specific NixOS config and Home Manager imports in
`hosts/<host>/default.nix`. Split into host-local topic files only when the
host entrypoint gets too large.

## Adding A Program To Specific Hosts

For one host, add the configuration directly to that host folder.

For a reusable feature, create or edit a module under `modules/`, then import it
from the host entrypoints that need it:

```nix
# hosts/nixos/default.nix
imports = [
  ../../modules/nixos/base.nix
  ../../modules/nixos/desktop-linux.nix
  ./x86.nix
];
```

For a home module, add it to that host's `default.nix` Home Manager import list:

```nix
# hosts/nixos/default.nix
home-manager.users.${config.dotfiles.users.primary.name}.imports = [
  ../../modules/home/base.nix
  ../../modules/home/cli.nix
  ../../modules/home/desktop-linux.nix
];
```

Do not import desktop modules into OrbStack or the server unless those hosts
actually need GUI programs.

## Adding A New Host

Create a new folder under `hosts/`:

```text
hosts/my-host/
├── default.nix
└── hardware.nix
```

Import the common option and base modules from `default.nix`, then set the
minimum host-specific value:

```nix
{ ... }:

{
  imports = [
    ../../modules/nixos/options/common.nix
    ../../modules/nixos/base.nix
    ./hardware.nix
  ];

  dotfiles.profile.name = "my-host";
}
```

The common defaults already cover the `joshan` user under `/home`, the `.files`
repo name, and the local Ollama URL. Set `dotfiles.users.primary.*`,
`dotfiles.paths.*`, `dotfiles.rebuild.flags`, or `dotfiles.services.ollama.url`
only when a host differs from those defaults.

Add it to `flake.nix`:

```nix
my-host = nixosHost {
  system = "x86_64-linux";
  hostModule = ./hosts/my-host;
};
```

## Editing Rebuild Commands

The shell aliases use these environment variables from `modules/nixos/base.nix`:

- `DOTFILES`
- `FLK_PROFILE`
- `NIXOS_REBUILD_FLAGS`
- `OLLAMA_URL`

Change the source values in each host's `dotfiles` block rather than editing the
aliases directly.

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

## Quick commands

Shell aliases are defined in [`modules/home/cli.nix`](modules/home/cli.nix):

### System management
- `sysup` - Rebuild and switch to new system configuration
- `systest` - Test system configuration without switching
- `sysvm` - Build and run NixOS VM with current config
- `sysfu` - Preview flake updates with validation and nvd diff
- `sysedit` - Edit configuration in VSCode

### Flake updates
- `scripts/flake-update <target> [options] [inputs...]` - Update flake inputs on a dedicated branch, compare the selected target against `main`, and evaluate the rest of the fleet
- Targets: `desktop`, `linux-desktop`, `nixos`, `server`, `nixos-server`, `orbstack`, `nixos-arm-parallels`, `nixos-orbstack`, `all`
- Darwin targets are not currently supported because this flake does not expose `darwinConfigurations`
- The script creates or switches to `system-upgrade` unless `UPDATE_BRANCH` is set
- The script allows pre-existing `flake.lock` worktree or index changes by default, so iterative update/fix/rerun cycles work; set `ALLOW_DIRTY_LOCK=0` to reject them
- Run this on a machine or remote builder that can build the selected target
- Non-target profiles are evaluated too; local-path availability errors are reported and skipped, but normal evaluation failures stop the update
- Run `sysfu` with no arguments to open the interactive selector; the first menu item chooses which `nixosConfiguration` to upgrade
- Use `--list-nixpkgs-commits [branch]` to print recent nixpkgs commits, for example `sysfu --list-nixpkgs-commits nixos-unstable`
- Use `--nixpkgs-ref <rev-or-ref>` to test a specific nixpkgs commit, branch, or flake ref, for example `scripts/flake-update nixos --nixpkgs-ref nixos-25.05`
- Use `--choose-nixpkgs-ref [branch]` to choose from recent nixpkgs commits, for example `sysfu --choose-nixpkgs-ref nixos-unstable`
- Use `--input-ref <input>=<flake-ref>` to pin another input explicitly, for example `scripts/flake-update nixos --input-ref home-manager=github:nix-community/home-manager/release-25.05`
- Dependency inspection helpers after an update: `nix-tree result` and `nix why-depends result /nix/store/...-package`

### Formatting
- `nix fmt` - Format all `.nix` files in this repo with treefmt
- `git config core.hooksPath .githooks` - Configure Git to run repo hooks from `.githooks/`

### Validation

After changing module imports or host wiring, run:

```sh
nix fmt
git diff --check
nix flake show
nix eval .#nixosConfigurations.nixos.config.system.build.toplevel.drvPath
nix eval .#nixosConfigurations.nixos-arm-parallels.config.system.build.toplevel.drvPath
nix eval .#nixosConfigurations.nixos-orbstack.config.system.build.toplevel.drvPath
nix eval .#nixosConfigurations.nixos-server.config.system.build.toplevel.drvPath
```

Build checks are useful on a Linux builder:

```sh
nix build .#nixosConfigurations.nixos.config.system.build.toplevel
nix build .#nixosConfigurations.nixos-orbstack.config.system.build.toplevel
nix build .#nixosConfigurations.nixos-server.config.system.build.toplevel
```

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
