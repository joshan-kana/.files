{ config, modulesPath, pkgs, ... }:

let
  firmwareTree = pkgs.runCommand "nixos-server-rpi-firmware" { } ''
    mkdir -p "$out"

    cp ${pkgs.raspberrypifw}/share/raspberrypi/boot/bootcode.bin "$out/"
    cp ${pkgs.raspberrypifw}/share/raspberrypi/boot/fixup*.dat "$out/"
    cp ${pkgs.raspberrypifw}/share/raspberrypi/boot/start*.elf "$out/"
    cp ${pkgs.ubootRaspberryPi4_64bit}/u-boot.bin "$out/u-boot-rpi4.bin"
    cp ${pkgs.raspberrypi-armstubs}/armstub8-gic.bin "$out/"
    cp ${pkgs.raspberrypifw}/share/raspberrypi/boot/bcm2711-rpi-4-b.dtb "$out/"
    cp ${pkgs.raspberrypifw}/share/raspberrypi/boot/bcm2711-rpi-400.dtb "$out/"
    cp ${pkgs.raspberrypifw}/share/raspberrypi/boot/bcm2711-rpi-cm4.dtb "$out/"
    cp ${pkgs.raspberrypifw}/share/raspberrypi/boot/bcm2711-rpi-cm4s.dtb "$out/"

    cat > "$out/config.txt" <<'EOF'
[pi4]
kernel=u-boot-rpi4.bin
enable_gic=1
armstub=armstub8-gic.bin
disable_overscan=1
arm_boost=1

[all]
arm_64bit=1
enable_uart=1
avoid_warnings=1
EOF
  '';

  bootTree = pkgs.runCommand "nixos-server-boot-tree" { } ''
    mkdir -p "$out/boot"
    ${config.boot.loader.generic-extlinux-compatible.populateCmd} \
      -c ${config.system.build.toplevel} \
      -d "$out/boot"
  '';
in
{
  imports = [ "${modulesPath}/image/repart.nix" ];

  image.repart = {
    name = "nixos-server";
    imageSize = "12G";
    compression.enable = true;
    compression.algorithm = "zstd";

    partitions = {
      esp = {
        contents = {
          "/".source = firmwareTree;
        };
        repartConfig = {
          Type = "esp";
          Format = "vfat";
          Label = "FIRMWARE";
          SizeMinBytes = "96M";
        };
      };

      root = {
        storePaths = [ config.system.build.toplevel ];
        nixStorePrefix = "/root";
        contents = {
          "/root/boot".source = "${bootTree}/boot";
        };
        repartConfig = {
          Type = "root";
          Format = "btrfs";
          Label = "NIXOS";
          Minimize = "guess";
          Subvolumes = [
            "/root"
            "/var-lib"
          ];
          MakeDirectories = [
            "/root"
            "/var-lib"
          ];
        };
      };
    };
  };
}
