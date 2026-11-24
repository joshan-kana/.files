# Installation guide for `nixos-orbstack`

`nixos-orbstack` is an ARM64 NixOS machine managed by OrbStack on the Mac. Its repository checkout is the Mac checkout mounted into the guest, so no separate clone is required inside the machine.

## Current evaluated target

```sh
{{#include ../../generated/hosts/nixos-orbstack.sh}}
```

## Create the machine

On the Mac, load the evaluated target environment and create the ARM64 NixOS machine:

```sh
orbctl create --arch arm64 nixos:unstable "$HOST_NAME"
```

Verify the generated OrbStack integration before applying the flake:

```sh
orb -m "$HOST_NAME" cat /etc/nixos/orbstack.nix \
  > "$DOTFILES_REPO/hosts/$HOST_NAME/generated.nix"
cd "$DOTFILES_REPO"
nix fmt "hosts/$HOST_NAME/generated.nix"
```

## Apply the configuration

The Mac checkout is mounted inside OrbStack at the evaluated repository path:

```sh
orb -m "$HOST_NAME" -u root nixos-rebuild switch \
  --flake "$DOTFILES_REPO#$HOST_NAME"
```

Verify the profile and the vendored OrbStack integration:

```sh
orb -m "$HOST_NAME" hostname
orb -m "$HOST_NAME" nixos-version
orb -m "$HOST_NAME" "$DOTFILES_REPO/scripts/check-orbstack-generated.sh"
```

## Restore or initialize host secrets backup

Enter the guest with `orb -m "$HOST_NAME"` and reload the evaluated target environment there. The Mac checkout is already available inside OrbStack, so no Git bootstrap is needed. Copy this host's external backup bootstrap files into the guest as `/tmp/rclone.conf` and `/tmp/secrets-restic-password`, then install them at the evaluated paths:

```sh
run0 install -d -m 0700 "$(dirname "$SECRETS_RCLONE_CONFIG")"
run0 install -m 0600 /tmp/rclone.conf "$SECRETS_RCLONE_CONFIG"
run0 install -m 0600 /tmp/secrets-restic-password "$SECRETS_PASSWORD_FILE"
```

When recovering an existing machine, restore its latest encrypted secrets snapshot and verify it:

```sh
run0 restic-secrets restore latest --target /
run0 restic-secrets snapshots --latest 1
```

On first-ever provisioning, initialize the repository once, run the first backup, and verify it instead:

```sh
run0 restic-secrets init
run0 systemctl start restic-backups-secrets.service
run0 restic-secrets snapshots --latest 1
```

Do not run `restic-secrets init` when recovering an existing repository.
