# Installation guide for `mac`

`mac` is the nix-darwin configuration for the existing MacBook. This is an
in-place migration, not a macOS reinstall. Keep the current applications,
secrets, and working services until their declarative replacements have been
verified. Do not activate this configuration unattended.

## Current evaluated target

The built manual generates these values from `darwinConfigurations.mac`. Load
them in the Mac shell before running commands that reference the variables:

```sh
{{#include ../../generated/hosts/mac.sh}}
```

## Prepare the Mac

Install a working Nix daemon first (the configuration uses Determinate Nix),
then make sure the `.files` checkout and its submodules are available at
`$DOTFILES_REPO`. Verify the target before making changes:

```sh
cd "$DOTFILES_REPO"
nix eval --raw .#darwinConfigurations.mac.config.system.build.toplevel.drvPath
nix eval --raw .#darwinConfigurations.mac.config.dotfiles.paths.repoPath
```

Before the first switch:

1. Verify a current Time Machine backup and a recoverable encrypted secrets
   snapshot. Keep the original backup scripts and LaunchAgent plists for
   rollback. Do not initialize a new Restic repository when recovering the
   existing one.
2. Restore the runtime backup credentials under
   `~/Library/Application Support/SecretsBackup`, and provision the Comin SSH
   deploy key and Attic upload token through the existing private secrets
   recovery process. Never put credential contents in Git or the Nix store.
3. Preserve the existing Hammerspoon, yabai, Karabiner, SSH, Tailscale and
   application settings. Check system-extension and Accessibility permissions,
   and arrange physical-console access before changing remote-access services.
4. Review the existing secrets-backup LaunchAgents. The replacement agents use
   the same labels; the old agents must not remain loaded alongside them.

Inspect the existing backup launchd jobs:

```sh
launchctl list | grep 'com.joshankana.secrets-backup' || true
```

## Build the configuration

From the repository checkout:

```sh
nix flake check --no-build
nix build --no-link .#darwinConfigurations.mac.system
```

Review the evaluated changes before switching. In the same maintenance session,
retain recovery copies of the old backup LaunchAgent plists, unload the existing
backup jobs, and remove their plists from `~/Library/LaunchAgents` so they do
not restart at login. Keep the original files available for rollback.

## Install

For the first activation, when `darwin-rebuild` is not yet on `PATH`:

```sh
cd "$DOTFILES_REPO"
sudo nix run github:nix-darwin/nix-darwin#darwin-rebuild -- \
  switch --flake ".#$HOST_NAME"
```

For subsequent changes, use the configured `sup` and `sbld` commands (`nh
darwin`). Do not remove existing Homebrew or vendor-managed apps merely because
Nix has installed another copy.

## Verify the installation

Check the system generation, managed services, and the replacement backup jobs:

```sh
sudo darwin-rebuild --list-generations
launchctl list | grep -E 'com.joshankana.(secrets-backup|attic-watch-store)' || true
nix eval --raw .#darwinConfigurations.mac.config.networking.hostName
```

Verify that there is exactly one scheduled secrets backup and maintenance job.
Run `secrets-backup backup`, check the new repository snapshot, and perform a
restore into a temporary directory before removing the old backup setup. Test
SSH from the server, Tailscale connectivity, Comin, Attic publication,
Hammerspoon/yabai and Karabiner. Confirm native applications open with their
existing data and macOS permissions before retiring any old installation.

## Rollback

If activation fails, use the previous nix-darwin generation:

```sh
sudo darwin-rebuild --rollback
```

Restore the preserved LaunchAgent plists and load the original backup jobs if
the new backup service has not been verified. Home Manager keeps conflicting
home files with the `.before-nix` suffix on first activation; inspect those
copies before changing the originals. Retain the working application bundles,
settings, licences and recovery backups until the new setup has survived a
reboot and a normal working session.
