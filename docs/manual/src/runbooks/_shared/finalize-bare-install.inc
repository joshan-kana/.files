## Finalize the target

The installer clone can create the primary home and checkout as root. After `nixos-install` has created the installed users, fix their ownership before rebooting:

```sh
sudo nixos-enter --root /mnt -c "chown -- '$PRIMARY_USER:users' '$PRIMARY_HOME'"
sudo nixos-enter --root /mnt -c "chown -R -- '$PRIMARY_USER:users' '$DOTFILES_REPO'"

if [[ -e "/mnt$USER_SECRETS_DIR" ]]; then
  sudo nixos-enter --root /mnt -c "chown -R -- '$PRIMARY_USER:users' '$USER_SECRETS_DIR'"
fi
```

Set a local password for a new or locked primary account before rebooting. Existing restored account passwords remain unchanged. The password is entered interactively and is not part of the Nix configuration:

```sh
sudo nixos-enter --root /mnt -c "passwd -S '$PRIMARY_USER'"
# If the account is locked (L) or has no password (NP), set one:
sudo nixos-enter --root /mnt -c "passwd '$PRIMARY_USER'"
```
