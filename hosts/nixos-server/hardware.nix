{ lib, pkgs, ... }:

{
  hardware.enableRedistributableFirmware = true;

  boot.loader.grub.enable = false;
  boot.loader.generic-extlinux-compatible.enable = true;
  boot.loader.generic-extlinux-compatible.configurationLimit = lib.mkDefault 10;
  # Headless Pi server: keep a tiny serial-console rescue window without
  # slowing normal unattended boots.
  boot.loader.timeout = lib.mkDefault 1;
  boot.kernelPackages = lib.mkForce pkgs.linuxPackages;

  boot.initrd.availableKernelModules = [
    "xhci_pci"
    "usbhid"
    "usb_storage"
    "uas"
    "sd_mod"
    "sdhci"
    "sdhci_pci"
    "sdhci_iproc"
    "sdhci_brcmstb"
    "mmc_block"
    "bcm2835_dma"
  ];

  fileSystems = {
    "/" = {
      device = "/dev/disk/by-label/NIXOS";
      fsType = "btrfs";
      options = [
        "compress=zstd"
        "noatime"
      ];
    };

    "/boot" = {
      device = "/dev/disk/by-label/FIRMWARE";
      fsType = "vfat";
    };

  };

  swapDevices = [ ];
  zramSwap = {
    enable = true;
    memoryPercent = 100;
  };

  boot.supportedFilesystems = [ "btrfs" ];
  boot.growPartition = true;

  nixpkgs.hostPlatform = lib.mkDefault "aarch64-linux";

  fileSystems."/".autoResize = true;
}
