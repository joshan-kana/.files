# Installation guide for `mac`

## Current evaluated target

Load the generated host environment in the installer shell before running
commands that reference the target configuration:

```sh
{{#include ../../generated/hosts/mac.sh}}
```

## Prepare the target

Install Nix, then make the repository and its submodules available at the
evaluated path:

```sh
cd "$DOTFILES_REPO"
nix eval --raw ".#darwinConfigurations.${HOST_NAME}.config.system.build.toplevel.drvPath"
```

Review the launchd jobs already loaded before installing their declarative
replacements. Preserve any existing job definitions that must be unloaded for
installation:

```sh
for label in "${MANAGED_LAUNCHD_LABELS[@]}"; do
  launchctl list "$label" || true
done
```

## Recover host secrets

{{#include ../_shared/secrets-recovery-prerequisites.inc}}

Skip this section when `SECRETS_BACKUP_ENABLED=false`. Otherwise stage the
external bootstrap files in `/tmp` under the filenames expected by the
generated environment, then install them with private permissions:

```sh
install -d -m 0700 "$(dirname "$SECRETS_RCLONE_CONFIG")"
install -m 0600 "/tmp/$(basename "$SECRETS_RCLONE_CONFIG")" "$SECRETS_RCLONE_CONFIG"
install -m 0600 "/tmp/$(basename "$SECRETS_PASSWORD_FILE")" "$SECRETS_PASSWORD_FILE"
```

For an existing repository, inspect its snapshots and restore the latest
secrets snapshot only when the target secrets directory can safely be replaced:

```sh
RCLONE_CONFIG="$SECRETS_RCLONE_CONFIG" \
  nix shell nixpkgs#restic nixpkgs#rclone -c restic \
  -r "$SECRETS_REPOSITORY" --password-file "$SECRETS_PASSWORD_FILE" \
  snapshots

RCLONE_CONFIG="$SECRETS_RCLONE_CONFIG" \
  nix shell nixpkgs#restic nixpkgs#rclone -c restic \
  -r "$SECRETS_REPOSITORY" --password-file "$SECRETS_PASSWORD_FILE" \
  restore latest --target / --include "$USER_SECRETS_DIR"
```

For a new repository, initialize it once instead of restoring:

```sh
RCLONE_CONFIG="$SECRETS_RCLONE_CONFIG" \
  nix shell nixpkgs#restic nixpkgs#rclone -c restic \
  -r "$SECRETS_REPOSITORY" --password-file "$SECRETS_PASSWORD_FILE" \
  init
```

Only initialize a repository that does not already exist.

## Install

```sh
cd "$DOTFILES_REPO"
sudo nix run github:nix-darwin/nix-darwin#darwin-rebuild -- \
  switch --flake ".#$HOST_NAME"
```

## Verify

Verify the active generation and the launchd jobs enabled by the evaluated
configuration:

```sh
sudo darwin-rebuild --list-generations
for label in "${MANAGED_LAUNCHD_LABELS[@]}"; do
  launchctl list "$label"
done
```

Verify that the restored secrets are accessible and that their encrypted
repository contains a recent snapshot. Check application and remote-access
functionality before relying on the installed configuration.
