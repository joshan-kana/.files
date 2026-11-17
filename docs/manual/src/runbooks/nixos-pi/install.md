# Installation guide for `nixos-pi`

This installation uses a flashable ARM64 NixOS SD-card image with a FAT `/boot` partition containing the firmware, extlinux configuration, kernel and initrd, alongside a Btrfs root filesystem. The root partition grows to fill the microSD card on first boot.

## Build the image

Build the stock NixOS SD-card image from the repository root using an `aarch64-linux` builder (for example, the OrbStack NixOS machine on macOS):

```sh
nix build .#nixos-pi-image --out-link /tmp/nixos-pi-image
```

The output is an uncompressed bootable disk image. Disabling image compression avoids repeated compression and decompression of the Btrfs root and complete SD image. No writable copy or image-provisioning step is necessary. On macOS, attach the microSD reader to the OrbStack NixOS machine before flashing. On native NixOS, operate directly on the removable card.

## Flash the microSD card

Run the following commands on Linux as root (`run0 zsh` on NixOS, or `orb -m nixos-orbstack -u root zsh` from the Mac). Ensure the raw image and source credentials are accessible in that environment. The image is written directly to the card without an intermediate copy.

Inspect the connected storage before choosing a device:

```sh
set -e
lsblk -o NAME,PATH,MODEL,TRAN,RM,SIZE,FSTYPE,MOUNTPOINTS
```

Use the full-disk path of the removable microSD card, not a partition. **Flashing irreversibly overwrites its existing contents.** A USB device must report `TRAN=usb` and `RM=1`; confirm the model and size as well.

```sh
printf 'MicroSD whole-disk path: '
read -r SD_DISK
lsblk -o NAME,PATH,MODEL,TRAN,RM,SIZE,FSTYPE,MOUNTPOINTS "$SD_DISK"

[ "$(lsblk -ndo TRAN "$SD_DISK")" = usb ] &&
  [ "$(lsblk -ndo RM "$SD_DISK")" = 1 ] || {
    echo 'Not a removable USB disk; refusing to flash.' >&2
    exit 1
  }

printf 'Type FLASH to erase the selected card: '
read -r CONFIRM
[ "$CONFIRM" = FLASH ] || exit 1

IMAGE=$(find -L /tmp/nixos-pi-image/sd-image -maxdepth 1 -name '*.img' -type f -print -quit)
[ -n "$IMAGE" ] || exit 1

dd if="$IMAGE" of="$SD_DISK" bs=4M status=progress conv=fsync
sync
blockdev --rereadpt "$SD_DISK"
udevadm settle
```

The same completed Nix store image can be reused for retries or another card. Never start another build just to locate the result. On macOS, leave the card attached to OrbStack until credentials have been installed.

## Install host credentials on the card

Prepare directories containing this host's required secrets and its Restic backup bootstrap credentials. The files must remain outside Git and the Nix store. Run the generated host exports in the same root shell:

```sh
{{#include ../../generated/hosts/nixos-pi.sh}}
```

Use the partitions of the **verified microSD device**, not another disk that happens to have the same labels:

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
[ -s "$PI_BACKUP_SOURCE/$(basename "$SECRETS_RCLONE_CONFIG")" ]
[ -s "$PI_BACKUP_SOURCE/$(basename "$SECRETS_PASSWORD_FILE")" ]

umask 077
mount -t "$ROOT_FS" "$ROOT_PART" /mnt/nixos-pi-root
MNT=/mnt/nixos-pi-root
install -d -m 0700 "$MNT$PRIMARY_HOME" "$MNT$USER_SECRETS_DIR"
cp -LR -- "$PI_SECRETS_SOURCE/." "$MNT$USER_SECRETS_DIR/"
find "$MNT$USER_SECRETS_DIR" -type d -exec chmod 0700 {} +
find "$MNT$USER_SECRETS_DIR" -type f -exec chmod 0600 {} +
install -d -m 0700 "$(dirname "$MNT$SECRETS_RCLONE_CONFIG")" "$(dirname "$MNT$SECRETS_PASSWORD_FILE")"
install -m 0600 "$PI_BACKUP_SOURCE/$(basename "$SECRETS_RCLONE_CONFIG")" "$MNT$SECRETS_RCLONE_CONFIG"
install -m 0600 "$PI_BACKUP_SOURCE/$(basename "$SECRETS_PASSWORD_FILE")" "$MNT$SECRETS_PASSWORD_FILE"
sync
umount /mnt/nixos-pi-root
```

Safely eject the card. On macOS, detach the USB reader from OrbStack before removing it. The installed credentials reside on an unencrypted filesystem: keep the card physically secure and do not publish or share its contents.

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

## Secrets backup

Reload the generated host exports before verifying or initializing its secrets backup:

```sh
{{#include ../../generated/hosts/nixos-pi.sh}}
```

{{#include ../_shared/secrets-backup-first-boot.inc}}

Test HDMI output and audio, MPV playback, and Jellyfin MPV Shim on the Pi. Video decoding and codec compatibility depend on the actual hardware and media. Reinstall by writing a current image to the card and copying the host credentials onto its root partition. Restore additional mutable data from its normal backups where applicable.
