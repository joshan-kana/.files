# Installation guide for `nixos-pi`

This installation uses a flashable ARM64 NixOS SD-card image with a FAT `/boot` partition containing the firmware, extlinux configuration, kernel and initrd, alongside a Btrfs root filesystem. The root partition grows to fill the installation drive on first boot.

## Build the image

Build the stock NixOS SD-card image from the repository root using an `aarch64-linux` builder (for example, the OrbStack NixOS machine on macOS):

```sh
nix build .#nixos-pi-image --out-link /tmp/nixos-pi-image
```

The output is an uncompressed bootable disk image. Disabling compression avoids repeatedly compressing the Btrfs root and complete disk image. No writable image copy is necessary. On macOS, flash directly using `diskutil` and `dd`; use OrbStack USB passthrough only when mounting Btrfs to install credentials.

## Flash the removable drive

Writing the image erases the entire selected drive. Verify its model, capacity, and removable USB identity immediately before flashing; macOS disk numbers change when drives are reconnected. Never select a disk based only on a previously observed number.

### macOS

The OrbStack NixOS guest builds the image, but macOS writes it directly to the USB drive:

```sh
GUEST_IMAGE=$(orb -m nixos-orbstack -u root sh -c 'find -L /tmp/nixos-pi-image/sd-image -maxdepth 1 -name "*.img" -print -quit')
IMAGE="$HOME/OrbStack/nixos-orbstack$(orb -m nixos-orbstack -u root realpath "$GUEST_IMAGE")"
test -f "$IMAGE" || exit 1

diskutil list external physical
printf 'Verified removable USB disk (for example disk7): '
read -r DISK
DISK="${DISK#/dev/}"
diskutil info "/dev/$DISK"

printf 'Type FLASH after verifying the disk model and size: '
read -r CONFIRM
[ "$CONFIRM" = FLASH ] || exit 1

diskutil unmountDisk "/dev/$DISK" &&
  sudo dd if="$IMAGE" of="/dev/r$DISK" bs=4m &&
  sync
```

Press Ctrl+T to display progress while `dd` runs. When it finishes, unmount the written partitions, locate the USB's current passthrough ID, and attach **only this drive** to OrbStack for Btrfs credential provisioning:

```sh
diskutil unmountDisk "/dev/$DISK"
orb usb list
printf 'Current USB passthrough ID: '
read -r USB_ID
orb usb attach "$USB_ID" -m nixos-orbstack
orb -m nixos-orbstack -u root sh
```

Inside OrbStack, use the Linux commands below only to verify and mount the flashed partitions, not to flash the drive again.

### Native Linux

Inspect the connected storage before choosing a device:

```sh
lsblk -o NAME,PATH,MODEL,SERIAL,TRAN,RM,SIZE,FSTYPE,MOUNTPOINTS
printf 'Verified removable USB whole-disk path: '
read -r SD_DISK
[ "$(lsblk -ndo TRAN "$SD_DISK")" = usb ] &&
  [ "$(lsblk -ndo RM "$SD_DISK")" = 1 ] || exit 1

printf 'Type FLASH after verifying the disk model and size: '
read -r CONFIRM
[ "$CONFIRM" = FLASH ] || exit 1

IMAGE=$(find -L /tmp/nixos-pi-image/sd-image -maxdepth 1 -name '*.img' -print -quit)
test -n "$IMAGE" || exit 1
dd if="$IMAGE" of="$SD_DISK" bs=4M status=progress conv=fsync
sync
blockdev --rereadpt "$SD_DISK"
udevadm settle
```

### Verify the flashed partitions

In the Linux root shell (native Linux or OrbStack), identify the **current** target device by model, serial, transport, capacity and removable status:

```sh
lsblk -o NAME,PATH,MODEL,SERIAL,TRAN,RM,SIZE,FSTYPE,LABEL,MOUNTPOINTS
printf 'Verified USB whole-disk path: '
read -r SD_DISK
[ "$(lsblk -ndo TRAN "$SD_DISK")" = usb ] &&
  [ "$(lsblk -ndo RM "$SD_DISK")" = 1 ] || exit 1
```

## Install host credentials on the installation drive

Prepare directories containing this host's required secrets and its Restic backup bootstrap credentials. The files must remain outside Git and the Nix store. Run the generated host exports in the same root shell:

```sh
{{#include ../../generated/hosts/nixos-pi.sh}}
```

Use the partitions of the **verified installation drive**, not another disk that happens to have the same labels:

```sh
BOOT_PART=$(lsblk -lnpo PATH "$SD_DISK" | sed -n '2p')
ROOT_PART=$(lsblk -lnpo PATH "$SD_DISK" | sed -n '3p')
[ "$(blkid -s LABEL -o value "$BOOT_PART")" = FIRMWARE ]
[ "$(blkid -s LABEL -o value "$ROOT_PART")" = "${ROOT_DEVICE##*/}" ]
[ "$(blkid -s TYPE -o value "$ROOT_PART")" = "$ROOT_FS" ]

mkdir -p /mnt/nixos-pi-boot /mnt/nixos-pi-root
mount -o ro "$BOOT_PART" /mnt/nixos-pi-boot
[ -s /mnt/nixos-pi-boot/u-boot.bin ]
[ -s /mnt/nixos-pi-boot/config.txt ]
[ -s /mnt/nixos-pi-boot/extlinux/extlinux.conf ]
umount /mnt/nixos-pi-boot

printf 'Host secrets directory: '
read -r PI_SECRETS_SOURCE
printf 'Backup bootstrap directory: '
read -r PI_BACKUP_SOURCE
[ -s "$PI_SECRETS_SOURCE/comin-github" ]
[ -s "$PI_SECRETS_SOURCE/attic-token" ]
[ -s "$PI_BACKUP_SOURCE/$(basename "$SECRETS_RCLONE_CONFIG")" ]
[ -s "$PI_BACKUP_SOURCE/$(basename "$SECRETS_PASSWORD_FILE")" ]

umask 077
mount -t "$ROOT_FS" "$ROOT_PART" /mnt/nixos-pi-root
MNT=/mnt/nixos-pi-root
for path in "$MNT" "$MNT/nix" "$MNT/nix/store" "$MNT/boot"; do
  [ "$(stat -c %u "$path")" = 0 ] || { echo "Incorrect root ownership: $path" >&2; exit 1; }
done
[ -L "$MNT/var/run" ] && [ "$(readlink "$MNT/var/run")" = ../run ] || {
  echo 'Missing /var/run link in the image.' >&2
  exit 1
}
if [ -n "$(find "$MNT/nix/store" -mindepth 1 -maxdepth 1 ! -uid 0 -print -quit)" ]; then
  echo 'Nix store contains incorrectly owned outputs.' >&2
  exit 1
fi
install -d -m 0700 "$MNT$PRIMARY_HOME" "$MNT$USER_SECRETS_DIR"
install -m 0600 "$PI_SECRETS_SOURCE/comin-github" "$MNT$USER_SECRETS_DIR/comin-github"
install -m 0600 "$PI_SECRETS_SOURCE/attic-token" "$MNT$USER_SECRETS_DIR/attic-token"
install -d -m 0700 "$(dirname "$MNT$SECRETS_RCLONE_CONFIG")" "$(dirname "$MNT$SECRETS_PASSWORD_FILE")"
install -m 0600 "$PI_BACKUP_SOURCE/$(basename "$SECRETS_RCLONE_CONFIG")" "$MNT$SECRETS_RCLONE_CONFIG"
install -m 0600 "$PI_BACKUP_SOURCE/$(basename "$SECRETS_PASSWORD_FILE")" "$MNT$SECRETS_PASSWORD_FILE"
sync
umount /mnt/nixos-pi-root
```

Safely unmount and eject the drive. On macOS, leave the OrbStack root shell and run `orb usb detach "$USB_ID"` using its current ID before unplugging the USB. The installed credentials reside on an unencrypted filesystem: keep the drive physically secure and do not publish or share its contents.

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

## Remote administration

Verify the Pi's SSH host-key fingerprint at its console:

```sh
ssh-keygen -lf /etc/ssh/ssh_host_ed25519_key.pub
```

On the Mac, connect using the `nixos-pi` SSH host profile. Confirm that the fingerprint shown on the first connection matches the Pi's console. The profile forwards the Mac SSH agent and loads the Pi's separate elevation key:

```sh
ssh-add --apple-use-keychain ~/.ssh/nixos-pi-sudo
ssh nixos-pi 'run0 -n id -u'
```

A successful `run0` verification prints `0` without requesting a password.

The ChatGPT shell gateway on `nixos-server` uses its own SSH login and elevation keys. Once the Pi is reachable, load the generated host exports in a server terminal and check its presented host key before trusting it:

```sh
{{#include ../../generated/hosts/nixos-pi.sh}}
```

```sh
ssh-keyscan -t ed25519 "$HOST_NAME.home" 2>/dev/null | ssh-keygen -lf -
```

Compare that fingerprint with the console output, then add the verified host key to the gateway account's known-hosts file:

```sh
ssh-keyscan -H -t ed25519 "$HOST_NAME.home" 2>/dev/null >> ~/.ssh/known_hosts
```

The remote target becomes accessible through ChatGPT Shell Access after the server has deployed the configuration containing that target and its SSH keys. Keep the Pi reachable by its configured LAN hostname.

## Recover a previous system generation

The Raspberry Pi firmware boots through U-Boot and an extlinux menu. When a new generation cannot mount the USB root filesystem, interrupt U-Boot's autoboot countdown and run:

```text
bootflow scan
```

Choose the last working `NixOS - Configuration ...` menu entry instead of `NixOS - Default`. On the recovered system, make its running generation the boot default again before attempting another upgrade:

```sh
run0 sh -c '
  set -eu
  system=$(readlink -f /run/current-system)
  nix-env --profile /nix/var/nix/profiles/system --set "$system"
  "$system/bin/switch-to-configuration" boot
'
```

Check `/boot/extlinux/extlinux.conf` and verify that the `nixos-default` entry points to the recovered generation's initrd. Keep the previous generation available until the replacement has booted successfully on the Pi. A successful build or bootloader installation alone is not a boot validation.

## Secrets backup

Reload the generated host exports before verifying or initializing its secrets backup:

```sh
{{#include ../../generated/hosts/nixos-pi.sh}}
```

{{#include ../_shared/secrets-backup-first-boot.inc}}

Test HDMI output and audio, MPV playback, and Jellyfin MPV Shim on the Pi. Video decoding and codec compatibility depend on the actual hardware and media. Reinstall by writing a current image to the drive and copying the host credentials onto its root partition. Restore additional mutable data from its normal backups where applicable.
