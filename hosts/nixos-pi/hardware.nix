{ lib, ... }:

{
  hardware.enableRedistributableFirmware = true;
  hardware.graphics.enable = true;

  # KWin needs more contiguous scanout memory at 2560x1440.
  boot.kernelParams = [ "cma=256M" ];

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
      device = "/dev/disk/by-label/ROOT";
      fsType = lib.mkForce "btrfs";
      options = [
        "compress=zstd"
        "noatime"
      ];
    };

    "/boot" = {
      device = "/dev/disk/by-label/FIRMWARE";
      fsType = "vfat";
      options = [ "umask=0077" ];
    };

    "/boot/firmware".enable = lib.mkForce false;
  };

  zramSwap = {
    enable = true;
    memoryPercent = 50;
  };

  nixpkgs.hostPlatform = lib.mkDefault "aarch64-linux";
}
