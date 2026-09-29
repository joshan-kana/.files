## Finalize the target

The installer clone can create the primary home and checkout as root. After `nixos-install` has created the installed users, fix their ownership before rebooting:

```sh
sudo nixos-enter --root /mnt -c "chown -- '$PRIMARY_USER:users' '$PRIMARY_HOME'"
sudo nixos-enter --root /mnt -c "chown -R -- '$PRIMARY_USER:users' '$DOTFILES_REPO'"

if [[ -e "/mnt$USER_SECRETS_DIR" ]]; then
  sudo nixos-enter --root /mnt -c "chown -R -- '$PRIMARY_USER:users' '$USER_SECRETS_DIR'"
fi
```
