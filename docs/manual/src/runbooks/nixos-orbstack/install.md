# Installation guide for `nixos-orbstack`

`nixos-orbstack` is an ARM64 NixOS machine managed by OrbStack on the Mac. Its repository checkout is the Mac checkout mounted into the guest, so no separate clone is required inside the machine.

## Current evaluated target

```sh
{{#include ../../generated/hosts/nixos-orbstack.sh}}
```

## Create the machine

On the Mac, create an ARM64 NixOS machine named `nixos-orbstack`:

```sh
orbctl create --arch arm64 nixos:unstable nixos-orbstack
```

Verify the generated OrbStack integration before applying the flake:

```sh
orb -m nixos-orbstack cat /etc/nixos/orbstack.nix \
  > ~/.files/hosts/nixos-orbstack/generated.nix
cd ~/.files
nix fmt hosts/nixos-orbstack/generated.nix
```

## Apply the configuration

The Mac repository is mounted inside OrbStack at `/Users/joshan/.files`:

```sh
orb -m nixos-orbstack -u root nixos-rebuild switch \
  --flake /Users/joshan/.files#nixos-orbstack
```

Verify the profile and the vendored OrbStack integration:

```sh
orb -m nixos-orbstack hostname
orb -m nixos-orbstack nixos-version
orb -m nixos-orbstack /Users/joshan/.files/scripts/check-orbstack-generated.sh
```

## Restore or initialize host secrets backup

The Mac checkout is already available inside OrbStack, so no Git bootstrap is needed. Copy this host's external backup bootstrap files into the guest as `/tmp/rclone.conf` and `/tmp/secrets-restic-password`, then install them at the evaluated paths:

```sh
sudo install -d -m 0700 "$(dirname "$SECRETS_RCLONE_CONFIG")"
sudo install -m 0600 /tmp/rclone.conf "$SECRETS_RCLONE_CONFIG"
sudo install -m 0600 /tmp/secrets-restic-password "$SECRETS_PASSWORD_FILE"
```

When recovering an existing machine, restore its latest encrypted secrets snapshot and verify it:

```sh
sudo restic-secrets restore latest --target /
sudo restic-secrets snapshots --latest 1
```

On first-ever provisioning, initialize the repository once, run the first backup, and verify it instead:

```sh
sudo restic-secrets init
sudo systemctl start restic-backups-secrets.service
sudo restic-secrets snapshots --latest 1
```

Do not run `restic-secrets init` when recovering an existing repository.
