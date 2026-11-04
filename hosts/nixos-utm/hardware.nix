{ lib, ... }:

{
  boot.initrd.availableKernelModules = [
    "virtio_pci"
    "virtio_blk"
    "virtio_scsi"
    "xhci_pci"
    "usbhid"
  ];

  fileSystems."/" = {
    device = "/dev/disk/by-label/ROOT";
    fsType = "btrfs";
    options = [
      "compress=zstd"
      "noatime"
    ];
  };

  fileSystems."/boot" = {
    device = "/dev/disk/by-label/BOOT";
    fsType = "vfat";
    options = [
      "fmask=0077"
      "dmask=0077"
    ];
  };

  hardware.graphics.enable = true;

  swapDevices = [ ];

  zramSwap = {
    enable = true;
    memoryPercent = 100;
  };

  networking.useDHCP = lib.mkDefault true;
  nixpkgs.hostPlatform = lib.mkDefault "aarch64-linux";
}
