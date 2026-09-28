# Install or recover `nixos-orbstack`

`nixos-orbstack` is an ARM64 NixOS machine managed by OrbStack on the Mac. Its repository checkout is the Mac checkout mounted into the guest, so no separate clone is required inside the machine.

## Current evaluated target

```sh
{{#include ../../generated/hosts/nixos-orbstack.sh}}
```

## Create the machine

On the Mac, create an ARM64 NixOS machine named `nixos`:

```sh
orbctl create --arch arm64 nixos:unstable nixos
```

The machine name intentionally remains `nixos`; the flake profile installed into it is `nixos-orbstack`.

Verify the generated OrbStack integration before applying the flake:

```sh
orb -m nixos cat /etc/nixos/orbstack.nix \
  > ~/.files/hosts/nixos-orbstack/generated.nix
cd ~/.files
nix fmt hosts/nixos-orbstack/generated.nix
```

## Apply the configuration

The Mac repository is mounted inside OrbStack at `/Users/joshan/.files`:

```sh
orb -m nixos -u root nixos-rebuild switch \
  --flake /Users/joshan/.files#nixos-orbstack
```

Verify the profile and the vendored OrbStack integration:

```sh
orb -m nixos hostname
orb -m nixos nixos-version
orb -m nixos /Users/joshan/.files/scripts/check-orbstack-generated.sh
```

Restore the host's backup bootstrap credentials and primary-user secrets before relying on its scheduled secret backup.
