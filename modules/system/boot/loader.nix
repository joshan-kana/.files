{ lib, system, ... }:
lib.optionalAttrs (lib.systems.elaborate system).isLinux {
  boot.loader = {
    systemd-boot.enable = true;
    efi.canTouchEfiVariables = true;
  };
}
