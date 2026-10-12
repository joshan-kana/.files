# Installation guide for `mac`

## Current evaluated target

Load the generated host environment in the installer shell before running
commands that reference the target configuration:

```sh
{{#include ../../generated/hosts/mac.sh}}
```

## Prepare the target

Install Nix and confirm network access before restoring the host's encrypted
secrets repository.

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

## Clone the configuration

Use the recovered Git SSH key, or the current SSH agent, to access the private
repository. Keep an existing checkout instead of cloning over it:

```sh
if [[ ! -d "$DOTFILES_REPO/.git" ]]; then
  mkdir -p "$(dirname "$DOTFILES_REPO")"
  if [[ -r "$USER_SECRETS_DIR/id_ed25519" ]]; then
    GIT_SSH_COMMAND="ssh -i $USER_SECRETS_DIR/id_ed25519 -o IdentitiesOnly=yes" \
      git clone --recurse-submodules git@github.com:joshan-kana/.files.git "$DOTFILES_REPO"
  else
    git clone --recurse-submodules git@github.com:joshan-kana/.files.git "$DOTFILES_REPO"
  fi
fi
cd "$DOTFILES_REPO"
nix eval --raw ".#darwinConfigurations.${HOST_NAME}.config.system.build.toplevel.drvPath"
```

Review any loaded launchd jobs before switching to their declarative
replacements. Preserve existing definitions that need to be unloaded:

```sh
for label in "${MANAGED_LAUNCHD_LABELS[@]}"; do
  launchctl list "$label" || true
done
```

## Install

Derive the bootstrap binary-cache settings from the target configuration,
using the Determinate Nix options that own them on macOS:

```sh
cd "$DOTFILES_REPO"

substituters="$(
  sudo nix --extra-experimental-features "nix-command flakes" eval --raw \
    ".#darwinConfigurations.$HOST_NAME" \
    --apply 'cfg: builtins.concatStringsSep " " (cfg.pkgs.lib.unique cfg.config.determinateNix.customSettings.extra-substituters)'
)"
trusted_public_keys="$(
  sudo nix --extra-experimental-features "nix-command flakes" eval --raw \
    ".#darwinConfigurations.$HOST_NAME" \
    --apply 'cfg: builtins.concatStringsSep " " (cfg.pkgs.lib.unique cfg.config.determinateNix.customSettings.extra-trusted-public-keys)'
)"
```

Pass the bootstrap settings both to `nix run` (which fetches the
`darwin-rebuild` command) and to `darwin-rebuild` (which builds the
system before the target Nix settings have been activated):

```sh
sudo nix --extra-experimental-features "nix-command flakes" \
  --option extra-substituters "$substituters" \
  --option extra-trusted-public-keys "$trusted_public_keys" \
  run github:nix-darwin/nix-darwin#darwin-rebuild -- \
  switch --flake ".#$HOST_NAME" \
  --option extra-substituters "$substituters" \
  --option extra-trusted-public-keys "$trusted_public_keys"
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
