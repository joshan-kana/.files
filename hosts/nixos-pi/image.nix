{
  config,
  lib,
  modulesPath,
  pkgs,
  ...
}:

{
  imports = [ "${modulesPath}/installer/sd-card/sd-image-aarch64.nix" ];

  # Use the same explicit boot drivers as the installed host.
  hardware.enableAllHardware = lib.mkForce false;

  boot.supportedFilesystems = lib.mkForce {
    btrfs = true;
    vfat = true;
  };

  fileSystems = {
    "/".fsType = lib.mkForce "btrfs";
    "/boot/firmware".enable = lib.mkForce false;
  };

  # Keep NixOS's SD-card firmware/U-Boot layout, but use Btrfs for the root
  # filesystem and resize it after extending the root partition at first boot.
  sdImage = {
    compressImage = false;
    firmwareSize = 512;
    # The pinned fakeroot lacks nftw() ownership emulation used by mkfs.btrfs.
    rootFilesystemImage = pkgs.callPackage (modulesPath + "/../lib/make-btrfs-fs.nix") {
      inherit (config.sdImage) storePaths compressImage;
      populateImageCommands = config.sdImage.populateRootCommands;
      volumeLabel = config.sdImage.rootVolumeLabel;
      fakeroot = pkgs.fakerootBtrfs;
    };

    # Boot files live on the firmware partition, not the underlying root filesystem.
    populateRootCommands = lib.mkForce ''
      mkdir -p files/boot files/var
      ln -s ../run files/var/run
    '';

    # The hardware profile owns firmware population; extlinux uses the same FAT partition.
    populateFirmwareCommands = lib.mkForce (
      lib.mkAfter ''
        ${config.boot.loader.generic-extlinux-compatible.populateCmd} -c ${config.system.build.toplevel} -d ./firmware
      ''
    );

    postBuildCommands = ''
      sfdisk --activate "$img" 1
    '';
  };

  systemd.services.register-nix-paths.requires = lib.optional config.sdImage.expandOnBoot "expand-root-partition.service";

  systemd.services.expand-root-partition.script = lib.mkForce ''
    rootPart=$(${lib.getExe' pkgs.util-linux "findmnt"} -n -o SOURCE /)
    device=$(${lib.getExe' pkgs.util-linux "lsblk"} -npo PKNAME "$rootPart")
    partition=$(${lib.getExe' pkgs.util-linux "lsblk"} -nro PARTN "$rootPart")
    test -n "$partition"
    printf ',+,\n' | ${lib.getExe' pkgs.util-linux "sfdisk"} -N "$partition" --no-reread "$device"
    ${lib.getExe' pkgs.util-linux "partx"} -u -n "$partition" "$device"
    ${lib.getExe' pkgs.btrfs-progs "btrfs"} filesystem resize max /
  '';
}
