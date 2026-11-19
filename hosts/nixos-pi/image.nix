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
    rootVolumeLabel = "ROOT";
    rootFilesystemCreator = ./make-btrfs-fs.nix;

    # Ensure early-boot services resolve /var/run to the writable /run tmpfs.
    populateRootCommands = lib.mkAfter ''
      mkdir -p files/var
      ln -s ../run files/var/run
    '';

    populateFirmwareCommands = lib.mkAfter ''
      mkdir -p firmware/overlays
      cp ${pkgs.raspberrypifw}/share/raspberrypi/boot/overlays/vc4-kms-v3d.dtbo firmware/overlays/
      chmod u+w firmware/config.txt
      cat >> firmware/config.txt <<'EOF_CONFIG'

      [pi4]
      dtoverlay=vc4-kms-v3d
      max_framebuffers=2
      EOF_CONFIG

      ${config.boot.loader.generic-extlinux-compatible.populateCmd} -c ${config.system.build.toplevel} -d ./firmware
    '';

    postBuildCommands = ''
      sfdisk --activate "$img" 1
    '';
  };

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
