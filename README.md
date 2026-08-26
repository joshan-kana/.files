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

Configuration is organised by **semantic ownership** rather than by evaluator.
`lib/semantic-scopes.nix` is a small module-system adapter: a scope contains
normal system options, function-valued attributes are nested semantic scopes,
and `home = { ... }: { ... };` switches into a real Home Manager module. The
same system-scope interface is intended for NixOS and future nix-darwin hosts.

```text
hosts/                    Machines, generated host state, and host-specific policy
modules/appimage/         Shared AppImage support
modules/audio/            Shared audio configuration
modules/cli/              Shared CLI system + Home Manager configuration
modules/desktop-apps/     Shared desktop application scopes
modules/desktop/          Desktop environments, display managers, and desktop policy
modules/networking/       Shared networking configuration
modules/nix/              Shared Nix configuration
modules/options/          Shared dotfiles option schema
modules/ssh/              Shared SSH configuration
modules/system/           Shared identity/locale/docs/compatibility scopes
modules/theme/            Shared theme policy and assets
modules/virtualisation/   Shared virtualisation, containers, and VM variants
overlays/                 Package overlays
lib/semantic-scopes.nix   Semantic scope engine
scripts/                  Helper scripts used by aliases and workflows
```

Host entrypoints are root semantic scopes. Keep genuine module-graph dependencies
(`imports`, option-schema modules, hardware modules) in their static `imports`;
put runtime configuration under semantic child scopes.

A cross-context feature stays in one scope:

```nix
git = { config, ... }:
  let
    settings = {
      init.defaultBranch = "main";
      user = {
        name = config.dotfiles.users.primary.fullName;
        email = config.dotfiles.users.primary.email;
      };
    };
  in
  {
    programs.git.config = settings;

    home = _: {
      programs.git.settings = settings;
    };
  };
```

The `home` branch is added through Home Manager `sharedModules`; user identity is
defined separately under `home-manager.users.<name>`. When NixOS/Home Manager
(or later nix-darwin/Home Manager) expose equivalent settings for the same
program, define the shared value once with ordinary Nix `let` bindings and feed
it into each native option path.

## Common Options

Shared host values live under `dotfiles.*`, defined in
`modules/options/default.nix`.

Common options include:

- `dotfiles.profile.name`
- `dotfiles.users.primary.name`
- `dotfiles.users.primary.fullName`
- `dotfiles.users.primary.email`
- `dotfiles.users.primary.homeRoot`
- `dotfiles.paths.repoName`
- `dotfiles.paths.repoPath`
- `dotfiles.rebuild.flags`
- `dotfiles.services.ollama.url`
- `dotfiles.scopes.<scope>.enable` for host-specific semantic scope overrides

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

## Adding And Editing Programs

Choose the semantic owner, not a separate NixOS/Home Manager layer.

| Where it should apply | Put it here |
| --- | --- |
| Shared CLI | `modules/cli/` |
| Shared desktop applications | `modules/desktop-apps/` |
| Shared audio/virtualisation | `modules/audio/`, `modules/virtualisation/` |
| Shared desktop | `modules/desktop/` |
| Display managers | `modules/desktop/display-manager/` |
| Hyprland | `modules/desktop/hyprland/default.nix` |
| Plasma | `modules/desktop/plasma/default.nix` |
| x86-only desktop inventory | inline scopes in `hosts/nixos/default.nix` |
| Parallels only | `hosts/nixos-arm-parallels/` |
| OrbStack only | `hosts/nixos-orbstack/default.nix` plus generated state |
| Server app | `hosts/nixos-server/apps/<app>/` |
| Server networking/storage/hardware | the matching file under `hosts/nixos-server/` |

Inside a semantic scope, write ordinary native options. If the concept also has
Home Manager configuration, add a `home` module in the same scope. Nested
function-valued attributes are child scopes and inherit the parent `enable`
gate. Do not invent app-specific DSL fields when native NixOS/Home Manager
options already express the configuration.

For example, an app-owned helper belongs under that app:

```nix
openclaw = { ... }: {
  virtualisation.oci-containers.containers.openclaw = { ... };

  ollamaMacBridge = { ... }: {
    services.nginx = { ... };
    systemd.services.openclaw-ollama-proxy = { ... };
  };
};
```

### Plasma generated state

`modules/desktop/plasma/default.nix` is the small handwritten semantic wrapper.
Plasma Manager's exported state lives in `modules/desktop/plasma/generated.nix`;
do not hand-edit that generated file. From the Plasma host, regenerate it with:

```sh
nix run .#update-plasma
```

The flake app uses the locked plasma-manager `rc2nix`, formats the result with the
repo's treefmt configuration, and only then replaces the generated file.

### Host-specific scope overrides

A host normally enables a semantic scope simply by importing it. To disable a
nested scope for one host, mirror its semantic path under `dotfiles.scopes`:

```nix
dotfiles.scopes.cli = {
  mpv.enable = false;
  tmuxai.enable = false;
};
```

Aliases belong to their owning scope and merge through native Home Manager
options. Disabling `cli.mpv`, for example, removes both MPV and its `p` alias.
Host-specific behavior overrides the native option directly; OrbStack overrides
`programs.zsh.shellAliases.cpd` in its `hostEnvironment.home` scope rather than
using an alias override registry.

### Themes

System and Home Manager theme policy live together in `modules/theme/`.
Desktop-specific target configuration remains with its owning desktop/program
scope. Keep the theme shared across hosts unless there is a real host-specific
requirement.

### System + Home Manager settings

When NixOS and Home Manager expose the **same native option path and shape**, use
a module-shaped `let` value and consume it in both contexts. Keeping the native
path inside that shared module gives nixd enough schema context for completion
and hover inside the `let` block itself:

```nix
let
  sharedZshConfig = _: {
    programs.zsh.enableCompletion = true;
  };
in
{
  zsh = args: {
    programs.zsh = (sharedZshConfig args).programs.zsh;

    home = args: {
      programs.zsh = (sharedZshConfig args).programs.zsh;
    };
  };
}
```

When the two native modules represent the same data with **different option
paths or schemas**, keep the common data in an ordinary `let` value and map it
into each native API explicitly. Git is the canonical example:

```nix
git = { config, ... }:
  let
    settings = {
      init.defaultBranch = "main";
      user = {
        name = config.dotfiles.users.primary.fullName;
        email = config.dotfiles.users.primary.email;
      };
    };
  in
  {
    programs.git.config = settings;

    home = _: {
      programs.git.settings = settings;
    };
  };
```

Prefer `dotfiles.*` options for reusable host/user/path/service policy that
should have one typed configuration source across modules. Use local `let`
values for implementation-local shared program data that does not warrant a
public dotfiles option.

## Adding A New Host

Create a new folder under `hosts/`:

```text
hosts/my-host/
├── default.nix
└── hardware.nix
```

Keep schema/hardware dependencies in static `imports`, then compose the host from
semantic scopes:

```nix
{ ... }:

{
  imports = [
    ../../modules/options
    ./hardware.nix
  ];

  system = import ../../modules/system;
  nix = import ../../modules/nix;
  cli = import ../../modules/cli;
  networking = import ../../modules/networking;
  virtualisation = import ../../modules/virtualisation;

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

The CLI scopes use these environment variables from `modules/cli/`:

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

Shell aliases are defined in [`modules/cli/`](modules/cli/):

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

- `nix fmt` or `fmt` - Apply repository formatting and safe fixes for Nix, Markdown, and Python, plus spelling fixes
- `nix flake check` or `chk` - Verify repository formatting, ShellCheck, YAML, GitHub Actions, and the existing flake checks without changing files
- `nix develop` - Enter the development shell and install the repository's pre-commit hooks

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
