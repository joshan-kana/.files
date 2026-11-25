{
  config,
  lib,
  pkgs,
  ...
}:

{
  hardware.enableRedistributableFirmware = true;
  # The cached vendor kernel predates these nixpkgs kernel metadata fields.
  hardware.deviceTree.enable = true;
  system.boot.loader.kernelFile = "Image";

  boot = {
    kernelPackages = pkgs.linuxPackages_rpi4;
    # Preserve firmware-applied KMS overlays and board-specific fixups.
    loader.generic-extlinux-compatible.useGenerationDeviceTree = false;
    # Fit the shared display and decoder buffers below the Pi 4 DMA limit.
    # U-Boot places the initrd below 512 MiB, preventing a 512 MiB reservation.
    kernelParams = [ "cma=384M" ];
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
      package = pkgs.raspberrypifw-rpi4;
      uboot.enable = true;
    };
    configtxt.settings.pi4.hdmi_enable_4kp60 = true;
  };

  # V4L2 request decoding allocates buffers through the DMA heap.
  services.udev.extraRules = ''
    SUBSYSTEM=="dma_heap", GROUP="video", MODE="0660"
  '';
  users.users.${config.dotfiles.users.primary.name}.extraGroups = [ "video" ];

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
