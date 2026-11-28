# Installation guide for `nixos-pi`

Build the installation image from the evaluated `nixos-pi` configuration. The image includes its boot files and root filesystem; the root partition expands on first boot.

## Current evaluated target

```sh
{{#include ../../generated/hosts/nixos-pi.sh}}
```

## Build the image

Build from the repository root on a Linux machine supporting the evaluated target architecture. On macOS, enter the OrbStack NixOS guest, open the same checkout, and load the generated target exports in that shell. Use the target's evaluated cache settings:

```sh
substituters="$(nix eval --raw ".#nixosConfigurations.$HOST_NAME" \
  --apply 'cfg: builtins.concatStringsSep " " (cfg.pkgs.lib.unique cfg.config.nix.settings.substituters)')"
trusted_public_keys="$(nix eval --raw ".#nixosConfigurations.$HOST_NAME" \
  --apply 'cfg: builtins.concatStringsSep " " (cfg.pkgs.lib.unique cfg.config.nix.settings.trusted-public-keys)')"

nix build ".#${HOST_NAME}-image" \
  --option extra-substituters "$substituters" \
  --option extra-trusted-public-keys "$trusted_public_keys" \
  --out-link "/tmp/${HOST_NAME}-image"
```

On macOS, write the image using `diskutil` and `dd`. Use OrbStack USB passthrough only when mounting the Linux root filesystem to install credentials.

## Flash the removable drive

Writing the image erases the entire selected drive. Verify its model, capacity, and removable USB identity immediately before flashing; macOS disk numbers change when drives are reconnected. Never select a disk based only on a previously observed number.

### macOS

The OrbStack NixOS guest builds the image, but macOS writes it directly to the USB drive. Load the generated target exports in the Mac shell before continuing:

```sh
GUEST_IMAGE=$(orb -m nixos-orbstack -u root find -L "/tmp/${HOST_NAME}-image/sd-image" -maxdepth 1 -name '*.img' -print -quit)
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
[ "$(lsblk -ndo TYPE "$SD_DISK")" = disk ] &&
  [ "$(lsblk -ndo TRAN "$SD_DISK")" = usb ] &&
  [ "$(lsblk -ndo RM "$SD_DISK")" = 1 ] || exit 1

printf 'Type FLASH after verifying the disk model and size: '
read -r CONFIRM
[ "$CONFIRM" = FLASH ] || exit 1

IMAGE=$(find -L "/tmp/${HOST_NAME}-image/sd-image" -maxdepth 1 -name '*.img' -print -quit)
test -n "$IMAGE" || exit 1
dd if="$IMAGE" of="$SD_DISK" bs=4M status=progress conv=fsync &&
  sync &&
  blockdev --rereadpt "$SD_DISK" &&
  udevadm settle
```

### Verify the flashed partitions

In the Linux root shell (native Linux or OrbStack), identify the **current** target device by model, serial, transport, capacity and removable status:

```sh
lsblk -o NAME,PATH,MODEL,SERIAL,TRAN,RM,SIZE,FSTYPE,LABEL,MOUNTPOINTS
printf 'Verified USB whole-disk path: '
read -r SD_DISK
[ "$(lsblk -ndo TYPE "$SD_DISK")" = disk ] &&
  [ "$(lsblk -ndo TRAN "$SD_DISK")" = usb ] &&
  [ "$(lsblk -ndo RM "$SD_DISK")" = 1 ] || exit 1
```

## Install host credentials on the installation drive

Load the evaluated target exports in the Linux root shell. For a host with an existing encrypted secrets repository, prepare only the external backup bootstrap files and restore the existing snapshot onto the mounted installation drive. For first-ever provisioning, prepare the required bootstrap credentials individually. Keep credentials outside Git and the Nix store.

Restore before first boot so the normal backup timer cannot snapshot an incomplete secrets tree. Do not initialize an existing repository.

Use the partitions of the **verified installation drive**, not another disk that happens to have the same labels:

```sh
(
  set -eu
  BOOT_PART=$(lsblk -nrpo PATH,PARTN "$SD_DISK" | awk '$2 == 1 {print $1}')
  ROOT_PART=$(lsblk -nrpo PATH,PARTN "$SD_DISK" | awk '$2 == 2 {print $1}')
  [ "$(blkid -s LABEL -o value "$BOOT_PART")" = "${BOOT_DEVICE##*/}" ]
  [ "$(blkid -s TYPE -o value "$BOOT_PART")" = "$BOOT_FS" ]
  [ "$(blkid -s LABEL -o value "$ROOT_PART")" = "${ROOT_DEVICE##*/}" ]
  [ "$(blkid -s TYPE -o value "$ROOT_PART")" = "$ROOT_FS" ]

  MNT=$(mktemp -d)
  trap 'if mountpoint -q "$MNT"; then umount "$MNT"; fi; rmdir "$MNT"' EXIT
  mount -t "$BOOT_FS" -o ro "$BOOT_PART" "$MNT"
  [ -s "$MNT/u-boot.bin" ]
  [ -s "$MNT/config.txt" ]
  [ -s "$MNT/extlinux/extlinux.conf" ]
  umount "$MNT"

  printf 'Installation type (new/recover): '
  read -r INSTALL_KIND
  case "$INSTALL_KIND" in
    new|recover) ;;
    *) exit 1 ;;
  esac
  test -n "$PRIMARY_UID"
  test -n "$PRIMARY_GID"

  umask 077
  mount -t "$ROOT_FS" "$ROOT_PART" "$MNT"
  for path in "$MNT" "$MNT/nix" "$MNT/nix/store" "$MNT/boot"; do
    [ "$(stat -c %u "$path")" = 0 ] || { echo "Incorrect root ownership: $path" >&2; exit 1; }
  done
  [ -L "$MNT/var/run" ] && [ "$(readlink "$MNT/var/run")" = ../run ]
  [ -z "$(find "$MNT/nix/store" -mindepth 1 -maxdepth 1 ! -uid 0 -print -quit)" ]

  install -d -o "$PRIMARY_UID" -g "$PRIMARY_GID" -m 0700 "$MNT$PRIMARY_HOME" "$MNT$USER_SECRETS_DIR"

  if [ "$SECRETS_BACKUP_ENABLED" = true ]; then
    printf 'Backup bootstrap directory: '
    read -r BACKUP_SOURCE
    for path in "$SECRETS_RCLONE_CONFIG" "$SECRETS_PASSWORD_FILE"; do
      test -s "$BACKUP_SOURCE/$(basename "$path")"
      install -d -m 0700 "$MNT$(dirname "$path")"
      install -m 0600 "$BACKUP_SOURCE/$(basename "$path")" "$MNT$path"
    done
  fi

  if [ "$INSTALL_KIND" = recover ] && [ "$SECRETS_BACKUP_ENABLED" = true ]; then
    env RCLONE_CONFIG="$MNT$SECRETS_RCLONE_CONFIG" \
      nix --extra-experimental-features "nix-command flakes" shell \
      nixpkgs#restic nixpkgs#rclone -c restic \
      -r "$SECRETS_REPOSITORY" \
      --password-file "$MNT$SECRETS_PASSWORD_FILE" \
      restore latest --target "$MNT"
  else
    printf 'Directory containing the required bootstrap files: '
    read -r SECRETS_SOURCE
    test -d "$SECRETS_SOURCE"
    printf '%s\n' "$USER_BOOTSTRAP_SECRET_FILES" | while IFS= read -r path; do
      [ -n "$path" ] || continue
      relative=${path#"$USER_SECRETS_DIR/"}
      test -s "$SECRETS_SOURCE/$relative"
      install -D -o "$PRIMARY_UID" -g "$PRIMARY_GID" -m 0600 "$SECRETS_SOURCE/$relative" "$MNT$path"
    done
  fi

  printf '%s\n' "$USER_BOOTSTRAP_SECRET_FILES" | while IFS= read -r path; do
    [ -n "$path" ] || continue
    test -s "$MNT$path"
    [ "$(stat -c %u "$MNT$path")" = "$PRIMARY_UID" ]
  done
  sync
  umount "$MNT"
)
```

If provisioning or restoration fails, correct the failure before booting. Safely unmount and eject the drive. On macOS, leave the OrbStack root shell and run `orb usb detach "$USB_ID"` using its current ID before unplugging the USB. The installed credentials reside on an unencrypted filesystem: keep the drive physically secure and do not publish or share its contents.

## First boot

Connect a keyboard, monitor, network and power. The root partition expands on first boot. The regular user and secret-directory ownership are initialized by NixOS.

Switch to a text console with Ctrl+Alt+F2, log in, and change the initial user password before connecting to untrusted networks:

```sh
passwd
```

Verify the system and graphical session:

```sh
hostname
findmnt -T /
findmnt -T /boot
lsblk -f
df -h /
systemctl status expand-root-partition register-nix-paths --no-pager
systemctl --failed --no-pager
systemctl --user --failed --no-pager
loginctl session-status
```

Confirm that the root filesystem has expanded to fill the installation drive.

## Clone the configuration

Reload the evaluated target exports. Git authentication is independent of service credentials: use the intended Git SSH identity or an authenticated forwarded agent.

As the primary user, clone the configuration if it is not already present:

```sh
if [ ! -d "$DOTFILES_REPO/.git" ]; then
  git clone --recurse-submodules git@github.com:joshan-kana/.files.git "$DOTFILES_REPO" || exit 1
fi
cd "$DOTFILES_REPO"
git fetch
nix eval --raw ".#nixosConfigurations.$HOST_NAME.config.system.build.toplevel.drvPath"
```

## Media and remote access

The graphical session starts automatically under the primary user. Physical access to the attached display and input devices grants access to that user's session. Keep the device physically secure. If the session fails to start, use the text console or SSH for recovery.

Configure application-managed accounts and pair remote-control or streaming clients using their normal interfaces. Validate representative media playback, HDMI audio, display mode and remote input on the physical device. See the [evaluated system reference](../../systems/nixos-pi.md) for configuration and packages.

Use the Kodi tile for native HDR playback. Kodi temporarily takes exclusive ownership of the display so its hardware decoder and video plane have sufficient contiguous memory. Its interface is rendered at up to 1080p while the video plane retains the native display mode. Quit Kodi to return to the launcher and its Wayland applications.

The WayVNC server and graphical Jellyfin cast receiver are available in the Wayland session, not during exclusive Kodi playback. Use Kodi's own input and media-library integration during that session. Physical input devices are available to the active local seat rather than through permanent input-group membership. In Kodi's HDMI-CEC adapter settings, disable powering off devices when stopping Kodi if the television should remain on when returning to the launcher.

For remote access, verify the SSH host-key fingerprint at the console before accepting it on a trusted client:

```sh
ssh-keygen -lf /etc/ssh/ssh_host_ed25519_key.pub
```

Verify agent-backed elevation from an authenticated SSH session with `run0 -n id -u`.

If VNC is enabled, use an authenticated SSH tunnel rather than exposing its listener directly:

```sh
ssh -N -L "$VNC_PORT:$VNC_ADDRESS:$VNC_PORT" "$HOST_NAME"
```

Connect to the forwarded local port. Application settings and paired devices remain mutable runtime data.

## Recover a previous system generation

Keep a known-working firmware partition backup before changing the boot pipeline. Firmware files are shared by boot generations, so selecting an older generation does not necessarily restore compatible firmware.

Select the last working generation from the U-Boot extlinux menu. On the recovered system, make the running generation the boot default:

```sh
run0 sh -c '
  set -eu
  system=$(readlink -f /run/current-system)
  nix-env --profile /nix/var/nix/profiles/system --set "$system"
  "$system/bin/switch-to-configuration" boot
'
```

Restore matching firmware and device-tree files from the backup if required. Reinstall by flashing a current image and restoring the host's normal credentials and backed-up runtime data.

{{#include ../_shared/secrets-backup-first-boot.inc}}
