{ lib, ... }:

{
  # Replace this with the real desktop hardware config before rebuilding the
  # `nixos` host:
  #
  #   sudo nixos-generate-config --show-hardware-config > hosts/nixos/hardware.nix
  #
  # Pure eval needs a root filesystem, so this disk-label default is only a
  # merge-readiness placeholder. Real rebuilds need the generated host hardware
  # settings from the desktop.
  fileSystems."/" = lib.mkDefault {
    device = "/dev/disk/by-label/NIXOS";
    fsType = "btrfs";
    options = [
      "compress=zstd"
      "noatime"
    ];
  };
}
