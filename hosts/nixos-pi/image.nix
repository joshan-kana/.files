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
    compressImage = false;
    firmwareSize = 512;
    rootVolumeLabel = "ROOT";
    rootFilesystemCreator = modulesPath + "/../lib/make-btrfs-fs.nix";
    # Older fakeroot releases miss nftw() ownership lookups used by mkfs.btrfs.
    # Prefer nixpkgs again as soon as it includes the upstream correction.
    rootFilesystemImage = pkgs.callPackage config.sdImage.rootFilesystemCreator (
      {
        inherit (config.sdImage) storePaths;
        compressImage = config.sdImage.compressImage;
        populateImageCommands = config.sdImage.populateRootCommands;
        volumeLabel = config.sdImage.rootVolumeLabel;
        fakeroot =
          if lib.versionAtLeast pkgs.fakeroot.version "2.0" then
            pkgs.fakeroot
          else
            pkgs.fakeroot.overrideAttrs {
              version = "2.1.4";
              src = pkgs.fetchurl {
                url = "https://deb.debian.org/debian/pool/main/f/fakeroot/fakeroot_2.1.4.orig.tar.xz";
                hash = "sha256-CCK9Wp8M8Z0roFRriLBDLU09mRfbYsV7dARMytugbkk=";
              };
              patches = [ ];
              postUnpack =
                builtins.replaceStrings [ "source/scripts/fakeroot.in" ] [ "$sourceRoot/scripts/fakeroot.in" ]
                  pkgs.fakeroot.postUnpack;
            };
      }
      // lib.optionalAttrs (config.sdImage.rootPartitionUUID != null) {
        uuid = config.sdImage.rootPartitionUUID;
      }
    );
    expandOnBoot = false;

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
