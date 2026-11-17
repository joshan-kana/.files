# Installation guide for `nixos-pi`

`nixos-pi` uses a flashable ARM64 NixOS SD-card image. The image inherits the workstation profile, with Raspberry Pi firmware and a Btrfs root filesystem. The FAT firmware partition remains separate from the root filesystem. No NixOS installer ISO or target-side partitioning is required.

The image is built without credentials, provisioned on the installation computer, then flashed to the microSD card. Flashing **erases the entire selected card**. Keep existing card data safe before proceeding.

## Current evaluated target

The generated environment below is derived from `nixosConfigurations.nixos-pi`, including host identity, filesystems and secret paths. These values replace manually maintained paths and labels in the installation commands:

```sh
{{#include ../../generated/hosts/nixos-pi.sh}}
```

To make this environment available to a shell outside the built manual, generate it from the current checkout:

```sh
nix build .#docs-source --out-link result-pi-docs
source result-pi-docs/src/generated/hosts/nixos-pi.sh
```

The remaining commands assume that the environment is loaded. Rebuild it after changing the host configuration; do not reuse values from an older revision.

## Build the image

A native `aarch64-linux` builder is required. On macOS, the configured OrbStack Linux builder can provide this; Linux ARM64 can build directly, while other systems need an ARM64 Linux builder or emulation.

```sh
nix build .#nixos-pi-image --out-link result-pi
IMAGE_DIR="$HOME/Downloads/$HOST_NAME"
mkdir -p -m 0700 "$IMAGE_DIR"
nix shell nixpkgs#zstd -c zstd -dc result-pi/sd-image/*.img.zst > "$IMAGE_DIR/system.img"
cp result-pi-docs/src/generated/hosts/nixos-pi.sh "$IMAGE_DIR/host.sh"
```

The built `.img.zst` and generated host configuration contain no secrets. The writable `system.img` is where credentials are provisioned; it must not be committed or uploaded.

## Provision the root filesystem

Use Linux to mount the Btrfs partition **inside the writable image**. A Mac can run the supplied Linux script through OrbStack; on Windows use a Linux VM with access to the image. The script checks the evaluated root label and filesystem before writing, then installs only the supplied secret files at the evaluated runtime paths and unmounts the image. No credentials pass through a Nix derivation or the FAT firmware partition.

Prepare a directory containing the secret files needed by this host, including the Git deployment key used by Comin. Keep service secrets from other hosts out of this directory. For encrypted secrets backups, prepare a second directory with the bootstrap files named by the evaluated `SECRETS_RCLONE_CONFIG` and `SECRETS_PASSWORD_FILE` paths.

Choose the source directories once:

```sh
printf '%s' 'Directory containing Pi secrets: '
read -r PI_SECRETS_SOURCE
printf 'Directory containing backup bootstrap files (blank to skip): '
read -r PI_BACKUP_SOURCE
```

On **macOS with OrbStack**, execute the provisioning script in the Linux guest:

```sh
PI_ARGS=("$IMAGE_DIR/host.sh" "$IMAGE_DIR/system.img" "$PI_SECRETS_SOURCE")
if [ -n "$PI_BACKUP_SOURCE" ]; then
  PI_ARGS+=("$PI_BACKUP_SOURCE")
fi
orb -m nixos-orbstack -u root bash \
  "$PWD/scripts/nixos-pi-provision-image.sh" "${PI_ARGS[@]}"
```

On **NixOS Linux**, run the same script through `run0`. Other Linux distributions can use their privileged execution tool (such as `sudo`) instead:

```sh
PI_ARGS=("$IMAGE_DIR/host.sh" "$IMAGE_DIR/system.img" "$PI_SECRETS_SOURCE")
if [ -n "$PI_BACKUP_SOURCE" ]; then
  PI_ARGS+=("$PI_BACKUP_SOURCE")
fi
run0 ./scripts/nixos-pi-provision-image.sh "${PI_ARGS[@]}"
```

The image is now credential-bearing. Protect it on encrypted local storage, keep the SD card under your control, and dispose of the writable image after the card is flashed. Deleting data from an SD card does not securely erase previously written blocks.

## Flash the card

Use [Raspberry Pi Imager](https://www.raspberrypi.com/software/) on macOS, Linux or Windows. Choose **Use custom** and select the provisioned `system.img`, then verify the destination SD card before flashing. Do not apply Raspberry Pi OS customization. Safely eject the card afterward.

Alternatively, use a trusted whole-disk flashing tool on the host OS. Never flash just the root partition: the complete image includes the Pi firmware partition and bootloader.

## First boot

Insert the SD card into the Pi and connect a keyboard, display and power. The image expands the root partition and Btrfs filesystem on first boot. Files installed under the evaluated user-secret path receive their normal ownership during system initialization.

The normal workstation account policy applies. **Change the initial login password immediately on the local console**, before connecting the machine to an untrusted network:

```sh
passwd
```

After networking is available, check the installed system and media stack:

```sh
hostname
findmnt -T /
lsblk -f
systemctl --failed --no-pager
systemctl status comin --no-pager
systemctl status display-manager --no-pager
```

Comin follows the approved branch after its Git key has been provisioned. Reload the generated environment before following the shared secrets-backup procedure on the Pi:

```sh
{{#include ../../generated/hosts/nixos-pi.sh}}
```

{{#include ../_shared/secrets-backup-first-boot.inc}}

Check HDMI graphics, sound, MPV and Jellyfin playback on the physical Pi. ARM64 evaluation does not establish hardware decoder support or smooth playback for any given format. To recover the machine, regenerate the image from the reviewed configuration, provision a fresh writable copy using the required runtime secrets, and reflash the SD card.
