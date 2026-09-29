## Restore existing host secrets when applicable

`SECRETS_BACKUP_ENABLED` comes from the evaluated target configuration. If it is `false`, skip this section.

For a host with secrets backup enabled, copy its external bootstrap files into the installer as `/tmp/rclone.conf` and `/tmp/secrets-restic-password`:

```sh
if [[ "$SECRETS_BACKUP_ENABLED" == true ]]; then
  sudo install -d -m 0700 "/mnt$(dirname "$SECRETS_RCLONE_CONFIG")"
  sudo install -m 0600 /tmp/rclone.conf "/mnt$SECRETS_RCLONE_CONFIG"
  sudo install -m 0600 /tmp/secrets-restic-password "/mnt$SECRETS_PASSWORD_FILE"
fi
```

When recovering an existing host, restore its latest secrets snapshot:

```sh
if [[ "$SECRETS_BACKUP_ENABLED" == true ]]; then
  sudo env RCLONE_CONFIG="/mnt$SECRETS_RCLONE_CONFIG" \
    nix --extra-experimental-features "nix-command flakes" shell \
    nixpkgs#restic nixpkgs#rclone -c restic \
    -r "$SECRETS_REPOSITORY" \
    --password-file "/mnt$SECRETS_PASSWORD_FILE" \
    restore latest --target /mnt
fi
```

On first-ever provisioning, skip the restore. The staged bootstrap files are used to initialize the repository after first boot.

## Clone the configuration

Git authentication is independent of Restic. Use whichever credential is available: the recovered host key, a forwarded SSH agent, or a temporary private key staged as `/tmp/dotfiles-git-key`.

```sh
if [[ -r "/mnt$USER_SECRETS_DIR/id_ed25519" ]]; then
  git_ssh_command="ssh -i /mnt$USER_SECRETS_DIR/id_ed25519 -o IdentitiesOnly=yes -o StrictHostKeyChecking=accept-new"
elif [[ -n "${SSH_AUTH_SOCK:-}" ]]; then
  git_ssh_command="ssh -o StrictHostKeyChecking=accept-new"
elif [[ -r /tmp/dotfiles-git-key ]]; then
  sudo chmod 0600 /tmp/dotfiles-git-key
  git_ssh_command="ssh -i /tmp/dotfiles-git-key -o IdentitiesOnly=yes -o StrictHostKeyChecking=accept-new"
else
  echo "No Git SSH credential is available." >&2
  false
fi

sudo mkdir -p "/mnt$(dirname "$DOTFILES_REPO")"
sudo env \
  SSH_AUTH_SOCK="${SSH_AUTH_SOCK:-}" \
  GIT_SSH_COMMAND="$git_ssh_command" \
  git clone --recurse-submodules \
  git@github.com:joshan-kana/.files.git \
  "/mnt$DOTFILES_REPO"

sudo rm -f /tmp/dotfiles-git-key
unset git_ssh_command
cd "/mnt$DOTFILES_REPO"
```

The checkout remains root-owned while installation is in progress. Ownership is fixed against the installed system after `nixos-install`.
