# Install `nixos-pi` on Raspberry Pi 4B

`nixos-pi` is an ARM64 media workstation for the Raspberry Pi 4B (8 GB), using the existing workstation profile with Pi-specific adjustments. The image includes the NixOS desktop and media applications, Raspberry Pi firmware, U-Boot, a FAT firmware partition and a Btrfs root filesystem with Zstd compression. The root partition and filesystem expand to fill the card on first boot.

The installation is prepared on another computer, including the secrets, **before** flashing the image to microSD. There is no temporary root SSH login, first-boot secrets importer or conventional installer ISO.

## Build the image

Use a computer with Nix and an `aarch64-linux` build machine. ARM64 Linux builds natively; macOS can use the existing OrbStack NixOS builder; x86_64 Linux can use a remote ARM64 builder or configured emulation. The output is independent of the host operating system.

From a checkout containing the new host:

```sh
cd ~/.files
nix build .#nixos-pi-image --out-link result-pi
mkdir -p ~/Downloads/nixos-pi
nix shell nixpkgs#zstd -c zstd -dc result-pi/sd-image/*.img.zst > ~/Downloads/nixos-pi/nixos-pi.img
```

The image contains two partitions: `FIRMWARE` (FAT) and `NIXOS_SD` (Btrfs). The Nix store build contains **no passwords, private keys or other runtime credentials**. The uncompressed `.img` is a separate writable copy that can be provisioned without modifying the immutable store result.

## Put the secrets in their final locations

Use a Linux environment to mount and modify the **Btrfs root partition inside the writable `.img`**. This works on Linux directly, and on macOS through the existing OrbStack NixOS machine. Windows also requires a Linux VM with access to the image file. Neither macOS nor Windows can directly mount Btrfs without additional drivers.

Prepare a local directory containing **only the secrets intended for this Pi**, including `comin-github`, the read-only Git deploy key Comin uses to fetch `.files`. Do not blindly copy the server's whole secrets tree. For an existing encrypted secrets-backup setup, also prepare a separate directory containing `rclone.conf` and `secrets-restic-password`.

The repository provides `scripts/nixos-pi-provision-image.sh` to mount the image's Btrfs partition, copy these files directly to the target locations and set the ordinary user password. It prompts for a new password and stores **only its salted hash** inside the image. It checks the partition label and filesystem before writing, then unmounts the filesystem and releases the loop device when finished.

On **macOS with OrbStack**, run this from the Mac terminal with paths to the real local directories:

```sh
orb -m nixos-orbstack -u root bash \
  "$HOME/.files/scripts/nixos-pi-provision-image.sh" \
  "$HOME/Downloads/nixos-pi/nixos-pi.img" \
  /path/to/pi-secrets \
  /path/to/pi-backup-credentials
```

On **Linux**, run the same script as root (using Nix-provided tools if your distribution lacks them):

```sh
sudo ./scripts/nixos-pi-provision-image.sh \
  "$HOME/Downloads/nixos-pi/nixos-pi.img" \
  /path/to/pi-secrets \
  /path/to/pi-backup-credentials
```

The final backup-credentials directory argument is optional if backup credentials have not yet been provisioned. In that case, scheduled secrets backups cannot succeed until they are supplied. On machines missing required utilities, use the repository's Nix environment or `nix shell nixpkgs#util-linux nixpkgs#whois` before running the script.

The script writes exactly these locations **inside the Btrfs root image**, with restrictive permissions and ownership:

```text
/home/joshan/.secrets/                      User secrets, including comin-github
/var/lib/backup-credentials/rclone.conf     Optional Restic transport configuration
/var/lib/backup-credentials/secrets-restic-password
/var/lib/nixos-pi/password-hash             Salted local-login password hash
```

**Protect the provisioned `.img` as secret-bearing material.** Unlike the Nix build output, this writable copy contains private credentials in plaintext on an unencrypted filesystem. Keep it on trusted encrypted storage, do not publish or back it up to shared locations, and delete the temporary `.img` after successful flashing. Files deleted from flash media may still be recoverable, so physical access to the card matters.

## Flash the microSD card

Use [Raspberry Pi Imager](https://www.raspberrypi.com/software/) (choose a *custom image*) or [balenaEtcher](https://etcher.balena.io/) on macOS, Linux or Windows. Select `nixos-pi.img` and verify the **correct microSD card** by size and device identity. Flashing destroys all partitions and data on the selected card. Do not use Raspberry Pi OS customization, which does not apply to this NixOS image.

Alternatively, on Linux or macOS, verify the disk first:

```sh
# Linux: identify the removable whole-disk device.
lsblk -o NAME,PATH,SIZE,MODEL,TRAN,RM,MOUNTPOINTS

# macOS: identify the removable whole-disk device.
diskutil list external physical
```

Unmount the card's existing partitions, then write the **whole disk**. Replace the example device with the one you verified:

```sh
# Linux example:
sudo dd if="$HOME/Downloads/nixos-pi/nixos-pi.img" of=/dev/sdX bs=4M status=progress conv=fsync
sync

# macOS example:
diskutil unmountDisk /dev/diskN
sudo dd if="$HOME/Downloads/nixos-pi/nixos-pi.img" of=/dev/rdiskN bs=4m
diskutil eject /dev/diskN
```

Use the graphical flasher if unsure of the device. Safely eject the card, insert it into the powered-off Pi, and connect wired Ethernet, HDMI and power. Remove the provisioned `.img` from the computer once flashing has been verified; keep the **unprovisioned** Nix build result if useful.

## First boot and deployment

On first boot, NixOS loads the installed Btrfs root filesystem, expands it to use the card, creates the ordinary user with the provisioned password hash, and reads the secrets from their final paths. The standard host configuration disables root SSH login; the ordinary user permits the key in `hosts/nixos-pi/authorized-key.pub`.

Log in at the keyboard using the password you chose during image provisioning, or use key-only SSH from a machine with the matching private key:

```sh
ssh joshan@nixos-pi.local
```

If mDNS is unavailable, locate the Pi by its DHCP lease and connect to that address. Comin uses `/home/joshan/.secrets/comin-github` to follow the approved `main` branch. **Merge the reviewed host PR before allowing unattended deployment.** If you want a normal local repository checkout as the Pi user, clone via the same read-only credential:

```sh
GIT_SSH_COMMAND="ssh -i $HOME/.secrets/comin-github -o IdentitiesOnly=yes" \
  git clone --recurse-submodules git@github.com:joshan-kana/.files.git ~/.files
```

For a **new** Pi secrets-backup repository, initialize and verify it after the backup credentials are present:

```sh
run0 restic-secrets init
run0 systemctl start restic-backups-secrets.service
run0 restic-secrets snapshots --latest 1
```

Do **not** initialize again when restoring an existing Pi repository. Do not restore `nixos-server` runtime state onto the Pi.

## Verify and recover

```sh
hostname
findmnt -T /
lsblk -f
systemctl status comin --no-pager
systemctl status display-manager --no-pager
systemctl --failed --no-pager
```

The firmware partition is mounted only on demand. Verify HDMI video and sound, a local MPV file, and Jellyfin MPV Shim playback from the existing Jellyfin server. Actual hardware video decoding, codec support and 4K smoothness still require physical playback testing.

Flashing again erases the card. Rebuild an unprovisioned image, provision a new writable copy from the intended secret sources, and flash it; recover additional app data separately from its normal backup owner.
