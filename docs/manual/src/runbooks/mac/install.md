# Installation guide for `mac`

This guide installs the evaluated nix-darwin host configuration. Use a local
terminal with administrator access and a working Nix daemon.

## Current evaluated target

Load the generated host environment in the shell before running the commands
below:

```sh
{{#include ../../generated/hosts/mac.sh}}
```

## Prepare the target

Check out the configuration and its submodules at the evaluated repository path,
then verify the host target:

```sh
cd "$DOTFILES_REPO"
nix eval --raw ".#darwinConfigurations.${HOST_NAME}.config.system.build.toplevel.drvPath"
```

Before installation, verify that a recent backup can be restored and that the
host's private secrets, backup credentials, Comin credentials, and cache token
are available. The backup and deployment modules define which runtime files
these services require; keep the credentials outside the Nix store.

Check for already loaded backup jobs before enabling their declarative
replacements:

```sh
launchctl list | grep -F "$BACKUP_JOB_LABEL" || true
launchctl list | grep -F "$BACKUP_MAINTENANCE_JOB_LABEL" || true
```

If existing backup jobs are loaded, preserve their plists for recovery and
unload them before switching. Do not initialize or overwrite an existing Restic
repository.

## Build

```sh
cd "$DOTFILES_REPO"
nix flake check --no-build
nix build --no-link ".#darwinConfigurations.${HOST_NAME}.system"
```

## Install

For the first activation, when `darwin-rebuild` is not on `PATH`:

```sh
sudo nix run github:nix-darwin/nix-darwin#darwin-rebuild -- \
  switch --flake ".#$HOST_NAME"
```

Use the configured `sup` or `sbld` commands for later updates and builds.

## Verify

Check the active generation and the launchd services configured for this host:

```sh
sudo darwin-rebuild --list-generations
launchctl list | grep -F "$BACKUP_JOB_LABEL" || true
launchctl list | grep -F "$BACKUP_MAINTENANCE_JOB_LABEL" || true
launchctl list | grep -F "$ATTIC_WATCH_JOB_LABEL" || true
```

Run `secrets-backup backup`, confirm that a repository snapshot was created, and
restore files into a temporary directory to verify recovery. Check SSH, Tailscale,
Comin, cache access, Hammerspoon, yabai, Karabiner and required applications.

## Rollback

To activate the previous nix-darwin generation:

```sh
sudo darwin-rebuild --rollback
```

If a previous backup job needs to be restored, reload its preserved plist and
verify the resulting schedule. Home Manager preserves conflicting files using
the evaluated suffix `$HOME_MANAGER_BACKUP_EXTENSION`; inspect those copies
before replacing any user files.
