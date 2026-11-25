{ lib, system, ... }:
lib.optionalAttrs (lib.systems.elaborate system).isLinux {
  boot = {
    plymouth.enable = true;
    kernelParams = [
      "quiet"
      "systemd.show_status=1"
    ];
  };
}
