# Installation guide for `nixos-pi`

This installation uses a flashable ARM64 NixOS SD-card image with a FAT firmware partition and a Btrfs root filesystem. The root partition grows to fill the microSD card on first boot.

## Target configuration

Run the generated exports in the shell used to prepare the image:

```sh
{{#include ../../generated/hosts/nixos-pi.sh}}
```

## Build the image

Build with an `aarch64-linux` builder. Native ARM64 Linux, a configured Linux remote builder, or the OrbStack NixOS builder on macOS can provide the required build environment.

From the repository root:

```sh
nix build .#nixos-pi-image --out-link result-pi
IMAGE_DIR="$HOME/Downloads/$HOST_NAME"
mkdir -p -m 0700 "$IMAGE_DIR"
nix shell nixpkgs#zstd -c zstd -dc result-pi/sd-image/*.img.zst > "$IMAGE_DIR/system.img"
```

Keep the compressed Nix build output unchanged. Provision only the writable `system.img` copy.

## Install credentials into the image

The provisioning script runs on Linux. On macOS, use the OrbStack NixOS machine to operate on the same image file. The script mounts the root partition inside the writable image and copies credentials to their configured runtime locations, without passing them through the Nix store.

Prepare a local directory containing only the credentials required by this host, including its Comin Git credential. If the host uses encrypted Restic backups, prepare a second directory with the bootstrap files named by `SECRETS_RCLONE_CONFIG` and `SECRETS_PASSWORD_FILE`.

```sh
printf '%s' 'Host secrets directory: '
read -r PI_SECRETS_SOURCE
printf '%s' 'Backup bootstrap directory (leave empty if unavailable): '
read -r PI_BACKUP_SOURCE

PI_ARGS=("$IMAGE_DIR/system.img" "$PI_SECRETS_SOURCE")
if [ -n "$PI_BACKUP_SOURCE" ]; then
  PI_ARGS+=("$PI_BACKUP_SOURCE")
fi

PI_ENV=(
  "ROOT_DEVICE=$ROOT_DEVICE"
  "ROOT_FS=$ROOT_FS"
  "PRIMARY_HOME=$PRIMARY_HOME"
  "USER_SECRETS_DIR=$USER_SECRETS_DIR"
  "SECRETS_RCLONE_CONFIG=$SECRETS_RCLONE_CONFIG"
  "SECRETS_PASSWORD_FILE=$SECRETS_PASSWORD_FILE"
)
```

On **macOS with OrbStack**:

```sh
orb -m nixos-orbstack -u root env "${PI_ENV[@]}" \
  bash "$(pwd -P)/scripts/nixos-pi-provision-image.sh" "${PI_ARGS[@]}"
```

On **NixOS Linux**:

```sh
run0 env "${PI_ENV[@]}" \
  bash ./scripts/nixos-pi-provision-image.sh "${PI_ARGS[@]}"
```

On another Linux distribution, run the same command with its supported privilege elevation tool instead of `run0`. The provisioning script requires `losetup`, `blkid`, `mount`, `find`, `install`, `realpath` and standard GNU utilities. Install missing tools through the distribution's existing environment or `nix shell nixpkgs#util-linux nixpkgs#coreutils`.

The provisioned image contains private credentials on an unencrypted filesystem. Keep it on trusted, encrypted local storage and delete it after successful flashing. Do not distribute the provisioned image.

## Flash the microSD card

Use [Raspberry Pi Imager](https://www.raspberrypi.com/software/) or [balenaEtcher](https://etcher.balena.io/) on macOS, Linux or Windows. Select **custom image**, choose `$IMAGE_DIR/system.img`, and confirm the destination device by model and capacity. Do not apply Raspberry Pi OS customization. Flashing overwrites the card's existing partitions and contents.

For command-line flashing, inspect the removable devices first:

```sh
# Linux
lsblk -o NAME,PATH,SIZE,MODEL,TRAN,RM,MOUNTPOINTS

# macOS
diskutil list external physical
```

On **Linux**, after unmounting any mounted partitions on the chosen card:

```sh
printf '%s' 'Whole-disk path for the microSD card: '
read -r SD_DISK
run0 dd if="$IMAGE_DIR/system.img" of="$SD_DISK" bs=4M status=progress conv=fsync
sync
```

On **macOS**:

```sh
printf '%s' 'MicroSD disk (such as /dev/diskN): '
read -r SD_DISK
diskutil unmountDisk "$SD_DISK"
sudo dd if="$IMAGE_DIR/system.img" of="/dev/r${SD_DISK#/dev/}" bs=4m
diskutil eject "$SD_DISK"
```

**Verify `SD_DISK` before running `dd`.** It must name the entire removable card, not an individual partition or the computer's internal drive. Safely eject the card and insert it into the powered-off Pi.

## First boot

Connect a keyboard, monitor, network and power. The Btrfs root partition expands on first boot. The regular user and secret-directory ownership are initialized by NixOS.

Change the initial workstation password at the local console before connecting to untrusted networks:

```sh
passwd
```

Check the system, deployer and desktop:

```sh
hostname
findmnt -T /
lsblk -f
systemctl --failed --no-pager
systemctl status comin --no-pager
systemctl status display-manager --no-pager
```

Reload the generated host exports before verifying or initializing its secrets backup:

```sh
{{#include ../../generated/hosts/nixos-pi.sh}}
```

{{#include ../_shared/secrets-backup-first-boot.inc}}

Test HDMI output and audio, MPV playback, and Jellyfin MPV Shim on the Pi. Video decoding and codec compatibility depend on the actual hardware and media. Reinstall by building a fresh image, provisioning it from the host's credential sources, and reflashing the card. Restore additional mutable data from its normal backups where applicable.
