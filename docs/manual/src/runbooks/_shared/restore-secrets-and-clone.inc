## Restore host secrets and clone the private repository

The private repository cannot be cloned until the host Git SSH key has been recovered. Copy the host backup bootstrap files from the external recovery store into the installer as `/tmp/rclone.conf` and `/tmp/secrets-restic-password`. When the installer is being used over SSH, `scp` is a convenient way to stage them.

Install those bootstrap files at the evaluated target paths:

```sh
sudo install -d -m 0700 "/mnt$(dirname "$SECRETS_RCLONE_CONFIG")"
sudo install -m 0600 /tmp/rclone.conf "/mnt$SECRETS_RCLONE_CONFIG"
sudo install -m 0600 /tmp/secrets-restic-password "/mnt$SECRETS_PASSWORD_FILE"
```

Restore this host's encrypted secrets backup into the mounted target:

```sh
sudo env RCLONE_CONFIG="/mnt$SECRETS_RCLONE_CONFIG" \
  nix --extra-experimental-features "nix-command flakes" shell \
  nixpkgs#restic nixpkgs#rclone -c restic \
  -r "$SECRETS_REPOSITORY" \
  --password-file "/mnt$SECRETS_PASSWORD_FILE" \
  restore latest --target /mnt
```

The restore uses the host's evaluated secrets-backup paths, so host-specific state included by that job is restored as well. The primary-user secret tree contains the Git SSH key needed for the private repository. Clone the configuration into its evaluated target path:

```sh
sudo mkdir -p "/mnt$(dirname "$DOTFILES_REPO")"
sudo env \
  GIT_SSH_COMMAND="ssh -i /mnt$USER_SECRETS_DIR/id_ed25519 -o IdentitiesOnly=yes -o StrictHostKeyChecking=accept-new" \
  git clone --recurse-submodules \
  git@github.com:joshan-kana/.files.git \
  "/mnt$DOTFILES_REPO"
cd "/mnt$DOTFILES_REPO"
```
