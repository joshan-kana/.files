{ lib, ... }:

{
  hardware.enableRedistributableFirmware = true;
  hardware.graphics.enable = true;

  boot.supportedFilesystems = {
    btrfs = true;
    zfs = lib.mkForce false;
  };
  boot.initrd.availableKernelModules = [
    "usbhid"
    "usb_storage"
    "sd_mod"
  ];

  # The SD image has a FAT firmware partition and a Btrfs root filesystem.
  fileSystems = {
    "/" = {
      device = "/dev/disk/by-label/NIXOS_SD";
      fsType = lib.mkForce "btrfs";
      options = [
        "compress=zstd"
        "noatime"
      ];
    };

    "/boot/firmware" = {
      device = "/dev/disk/by-label/FIRMWARE";
      fsType = "vfat";
      options = [
        "noauto"
        "nofail"
      ];
    };
  };

  zramSwap = {
    enable = true;
    memoryPercent = 50;
  };

  nixpkgs.hostPlatform = lib.mkDefault "aarch64-linux";
}
