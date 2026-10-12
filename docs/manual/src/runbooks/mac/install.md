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

## Restore host secrets

Use the existing backup credentials at `$SECRETS_RCLONE_CONFIG` and
`$SECRETS_PASSWORD_FILE`. If either is missing, recover it **directly to its
evaluated path** from secure recovery material (directory mode `0700`, file mode
`0600`). No temporary staging is required.

When restoring an existing repository, first inspect its snapshots:

```sh
if [[ "$SECRETS_BACKUP_ENABLED" == true ]]; then
  RCLONE_CONFIG="$SECRETS_RCLONE_CONFIG" \
    nix shell nixpkgs#restic nixpkgs#rclone -c restic \
    -r "$SECRETS_REPOSITORY" --password-file "$SECRETS_PASSWORD_FILE" \
    snapshots
fi
```

After confirming that the destination can safely be restored, recover its latest
secrets snapshot:

```sh
if [[ "$SECRETS_BACKUP_ENABLED" == true ]]; then
  RCLONE_CONFIG="$SECRETS_RCLONE_CONFIG" \
    nix shell nixpkgs#restic nixpkgs#rclone -c restic \
    -r "$SECRETS_REPOSITORY" --password-file "$SECRETS_PASSWORD_FILE" \
    restore latest --target / --include "$USER_SECRETS_DIR"
fi
```

For a repository that does not yet exist, initialize it once instead of
restoring:

```sh
if [[ "$SECRETS_BACKUP_ENABLED" == true ]]; then
  RCLONE_CONFIG="$SECRETS_RCLONE_CONFIG" \
    nix shell nixpkgs#restic nixpkgs#rclone -c restic \
    -r "$SECRETS_REPOSITORY" --password-file "$SECRETS_PASSWORD_FILE" \
    init
fi
```

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
