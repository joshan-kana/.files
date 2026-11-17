{
  config,
  lib,
  modulesPath,
  pkgs,
  ...
}:

{
  imports = [ "${modulesPath}/installer/sd-card/sd-image-aarch64.nix" ];

  # Keep NixOS's SD-card firmware/U-Boot layout, but use Btrfs for the root
  # filesystem and resize it after extending the root partition at first boot.
  sdImage = {
    firmwareSize = 512;
    rootVolumeLabel = "ROOT";
    rootFilesystemCreator = modulesPath + "/../lib/make-btrfs-fs.nix";
    expandOnBoot = false;

    populateFirmwareCommands = lib.mkAfter ''
      mkdir -p firmware/overlays
      cp ${pkgs.raspberrypifw}/share/raspberrypi/boot/overlays/vc4-kms-v3d.dtbo firmware/overlays/
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

  systemd.services.expand-root-partition = {
    description = "Expand Raspberry Pi Btrfs root partition on first boot";
    wantedBy = [ "sysinit.target" ];
    unitConfig = {
      DefaultDependencies = false;
      ConditionPathExists = config.sdImage.nixPathRegistrationFile;
    };
    before = [
      "sysinit.target"
      "shutdown.target"
      "register-nix-paths.service"
    ];
    after = [ "local-fs.target" ];
    conflicts = [ "shutdown.target" ];
    restartIfChanged = false;
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      root_part=$(${lib.getExe' pkgs.util-linux "findmnt"} -n -o SOURCE /)
      device=$(${lib.getExe' pkgs.util-linux "lsblk"} -npo PKNAME "$root_part")
      partition=$(${lib.getExe' pkgs.util-linux "lsblk"} -nro PARTN "$root_part")
      test -n "$partition"
      printf ',+,\n' | ${lib.getExe' pkgs.util-linux "sfdisk"} -N "$partition" --no-reread "$device"
      ${lib.getExe' pkgs.util-linux "partx"} -u -n "$partition" "$device"
      ${lib.getExe' pkgs.btrfs-progs "btrfs"} filesystem resize max /
    '';
  };
}
