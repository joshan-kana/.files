{ lib, ... }:

{
  hardware.enableRedistributableFirmware = true;

  boot = {
    kernelParams = [ "cma=256M" ];
    supportedFilesystems.btrfs = true;

    initrd.availableKernelModules = [
      "uas"
      "sd_mod"
    ];
  };

  hardware.raspberry-pi = {
    firmware = {
      enable = true;
      path = "/boot";
      uboot.enable = true;
    };
    configtxt.settings.pi4.hdmi_enable_4kp60 = true;
  };

  fileSystems = {
    "/" = {
      device = "/dev/disk/by-label/ROOT";
      fsType = "btrfs";
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
  };

  zramSwap = {
    enable = true;
    memoryPercent = 100;
  };

  nixpkgs.hostPlatform = lib.mkDefault "aarch64-linux";
}
