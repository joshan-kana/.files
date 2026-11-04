# Installation guide for `nixos-utm`

`nixos-utm` is an AArch64 NixOS desktop guest running under the UTM QEMU backend. It uses the shared Hyprland and Quickshell configuration so rendering and frame pacing can be compared with the Parallels guest.

## VM configuration

Create a **Virtualize → Linux** VM in UTM with an AArch64 NixOS installer ISO and the following devices:

- **4 CPU cores**, **8 GiB RAM**, and a sparse **64 GiB VirtIO disk**.
- UEFI firmware and a VirtIO network interface using shared networking.
- Btrfs root with zstd compression, plus 100% of guest RAM allocated as compressed zram swap (no disk-backed swap).
- A **VirtIO GPU (GPU Supported)** display, backed by `virtio-gpu-gl-pci` where available.

Keep the renderer, display resolution, refresh rate and guest configuration consistent when comparing builds. Vulkan support through Venus depends on UTM's host renderer as well as the Linux guest drivers.

Load the generated target environment in the installer shell before using shared installation commands:

```sh
{{#include ../../generated/hosts/nixos-utm.sh}}
```

If needed, enable [installer SSH](../common/nixos-installer-ssh.md). On some UTM shared networks, the gateway's DNS forwarder may not resolve public names even when routing works. Verify with `resolvectl query github.com`; if necessary, temporarily specify public resolvers for the installer connection:

```sh
sudo resolvectl dns enp0s1 1.1.1.1 8.8.8.8
sudo resolvectl flush-caches
```

This only adjusts the live installer session. Public DNS may not resolve the
private `.home` zone used by the build cache, so ensure both `github.com` and
`nixos-server.home` resolve before installing. Use a LAN resolver if needed;
diagnose any recurring DNS issue in the installed guest separately.

Before installing the full desktop closure, enable compressed zram swap in the *live installer* too. This is separate from the persistent `zramSwap` configuration applied after installation:

```sh
sudo modprobe zram
sudo zramctl --find --algorithm zstd --size 8G
sudo mkswap /dev/zram0
sudo swapon /dev/zram0
swapon --show
```

zram's configured size is the logical uncompressed swap capacity, not 8 GiB of preallocated host RAM.

## Partition and mount

Identify the **new empty guest disk** before partitioning:

```sh
lsblk -o NAME,PATH,SIZE,TYPE,FSTYPE,LABEL,MOUNTPOINTS
```

The following commands assume the guest's VirtIO disk is `/dev/vda`, with no data that must be preserved. Replace device paths if UTM exposes a different disk. **The partitioning step erases the selected disk's partition table.**

```sh
disk=/dev/vda
sudo parted --script "$disk" \
  mklabel gpt \
  mkpart ESP fat32 1MiB 1025MiB \
  set 1 esp on \
  mkpart ROOT 1025MiB 100%

sudo mkfs.vfat -n BOOT /dev/vda1
sudo mkfs.btrfs -f -L ROOT /dev/vda2

sudo mount /dev/disk/by-label/ROOT /mnt
sudo mkdir -p /mnt/boot
sudo mount /dev/disk/by-label/BOOT /mnt/boot
```

{{#include ../_shared/restore-secrets-and-clone.inc}}

## Install the test branch

The installer must use the target's evaluated binary caches, including Attic,
instead of the installation image's defaults. Attic is readable without a
client token on the private network. The installed Linux `attic-client` watcher
also publishes new paths; that separate operation requires a host-scoped
push token at `$USER_SECRETS_DIR/attic-token`. Stage it outside Git at
`/mnt$USER_SECRETS_DIR/attic-token` with mode `0600` before first boot if
publishing is enabled. The finalization step below corrects ownership.

The host is intentionally maintained on an unmerged `.files` PR rather than `main`. The shared clone procedure above uses an authenticated Git SSH credential, including for the infrastructure-docs submodule. Fetch the public PR ref separately, then switch the installer checkout to it:

```sh
cd "/mnt$DOTFILES_REPO"
utm_host_pr=541
sudo git fetch https://github.com/joshan-kana/.files.git \
  "pull/$utm_host_pr/head:refs/heads/utm-test-host"
sudo git switch utm-test-host

substituters="$(
  sudo nix --extra-experimental-features "nix-command flakes" eval --raw \
    .#nixosConfigurations.nixos-utm \
    --apply 'cfg: builtins.concatStringsSep " " (cfg.pkgs.lib.unique cfg.config.nix.settings.substituters)'
)"
trusted_public_keys="$(
  sudo nix --extra-experimental-features "nix-command flakes" eval --raw \
    .#nixosConfigurations.nixos-utm \
    --apply 'cfg: builtins.concatStringsSep " " (cfg.pkgs.lib.unique cfg.config.nix.settings.trusted-public-keys)'
)"

sudo nixos-install \
  --no-root-password \
  --option extra-experimental-features "nix-command flakes" \
  --option extra-substituters "$substituters" \
  --option extra-trusted-public-keys "$trusted_public_keys" \
  --flake ".#nixos-utm"
```

{{#include ../_shared/finalize-bare-install.inc}}

Detach the installer ISO and reboot. Verify the guest session, and replace the initial user password. Rebuild only from the checked-out review branch:

```sh
cd ~/.files
git status -sb
run0 nixos-rebuild switch --flake .#nixos-utm
```

Comin automatic deployments are disabled for this guest. To update the reviewed configuration, fetch and inspect the PR revision explicitly before rebuilding.

## Graphics validation

Record the **actual guest renderer** and hardware driver rather than relying on an advertised API version:

```sh
lspci -nnk | grep -A 3 -Ei 'vga|display'
glxinfo -B
vulkaninfo --summary
```

Check Zink in a separate process instead of forcing it on Hyprland:

```sh
MESA_LOADER_DRIVER_OVERRIDE=zink glxinfo -B
```

Treat `llvmpipe` or another software renderer as a failed hardware-acceleration test. Validate Hyprland, Quickshell, window resizing, transparency and Vulkan/OpenGL workloads in a live desktop session. Compare idle CPU/GPU use, memory, frame pacing and visual correctness against an otherwise identical, unmodified UTM build.
