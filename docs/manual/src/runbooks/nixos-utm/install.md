# Installation guide for `nixos-utm`

`nixos-utm` is an ARM64 NixOS desktop guest on the Mac, running under UTM with QEMU's VirtIO GPU. It uses the shared Hyprland/Quickshell configuration so graphical rendering can be compared with the Parallels guest.

## Guest configuration

In UTM, create a **Virtualize → Linux** VM using an AArch64 NixOS installer ISO, with UEFI, a VirtIO disk, a VirtIO network interface and a VirtIO GPU display. Select the GPU-accelerated display variant when available. Keep the GPU and renderer selection consistent across before/after comparisons; Venus/Vulkan availability depends on the host renderer, not only the guest configuration.

Start with 4 CPU cores, 8 GiB RAM and a sparse 64 GiB disk, adjusting to available host resources. The UTM guest has its own disk image and machine identity.

Use the generated target settings when this runbook is rendered:

```sh
{{#include ../../generated/hosts/nixos-utm.sh}}
```

Installers can enable [temporary SSH access](../common/nixos-installer-ssh.md) after networking starts.

## Partition and mount

Inspect the selected guest disk carefully before changing it:

```sh
lsblk -o NAME,PATH,SIZE,TYPE,FSTYPE,LABEL,MOUNTPOINTS
```

For a *new, empty VirtIO disk* exposed as `/dev/vda`, the following initializes an EFI partition and an ext4 root partition. Replace device paths if UTM exposes another disk. **The partitioning command destroys any existing partition table on the selected disk.**

```sh
disk=/dev/vda
sudo parted --script "$disk"   mklabel gpt   mkpart ESP fat32 1MiB 1025MiB   set 1 esp on   mkpart primary ext4 1025MiB 100%
sudo mkfs.vfat -n BOOT /dev/vda1
sudo mkfs.ext4 -L ROOT /dev/vda2
sudo mount /dev/disk/by-label/ROOT /mnt
sudo mkdir -p /mnt/boot
sudo mount /dev/disk/by-label/BOOT /mnt/boot
```

## Install from the review branch

The host remains on a review branch in `.files`, rather than `main`. In the installer, clone the repository to the target location, set `PR_NUMBER` to the current host PR number, fetch that PR, then select it before installation.

```sh
sudo mkdir -p /mnt/home/joshan
sudo git clone --recurse-submodules   https://github.com/joshan-kana/.files.git   /mnt/home/joshan/.files

cd /mnt/home/joshan/.files
utm_host_pr=<PR_NUMBER>
sudo git fetch origin "pull/${utm_host_pr}/head:refs/heads/utm-test-host"
sudo git switch utm-test-host

sudo nixos-install   --option extra-experimental-features "nix-command flakes"   --flake ".#nixos-utm"
```

The checkout is owned by root during installation. After the installed user exists, restore ownership before rebooting:

```sh
sudo nixos-enter --root /mnt -c "chown -R joshan:users /home/joshan/.files"
```

Detach the installer ISO and restart. Change the initial console password with `passwd`, then verify the guest session and rebuild only from the checked-out test branch:

```sh
cd ~/.files
git status -sb
run0 nixos-rebuild switch --flake .#nixos-utm
```

Automatic Comin deployments are disabled for this guest. To evaluate a new review revision, fetch the branch explicitly, inspect the diff, then rebuild.

## Graphics validation

Check the device driver and **real accelerated renderer**, not just an advertised API version:

```sh
lspci -nnk | grep -A 3 -Ei 'vga|display'
glxinfo -B
vulkaninfo --summary
```

For OpenGL over Vulkan, test Zink per process rather than forcing it on the compositor:

```sh
MESA_LOADER_DRIVER_OVERRIDE=zink glxinfo -B
```

Record `llvmpipe`/software-renderer fallbacks as a failure of GPU acceleration. For Wayland, confirm Hyprland, Quickshell, animations and GPU workloads in a live session, along with CPU, memory, idle consumption and frame pacing. Run equivalent tests on an unmodified UTM build for comparison.
