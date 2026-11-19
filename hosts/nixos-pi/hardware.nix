{ lib, ... }:

{
  hardware.enableRedistributableFirmware = true;

  boot = {
    kernelParams = [ "cma=256M" ];
    supportedFilesystems.btrfs = true;

    # The Pi 4 USB controller sits behind Broadcom PCIe.
    initrd.availableKernelModules = [
      "pcie-brcmstb"
      "uas"
      "usbhid"
      "usb_storage"
      "sd_mod"
    ];

    loader = {
      grub.enable = false;
      generic-extlinux-compatible = {
        enable = true;
        configurationLimit = 5;
      };
    };
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
