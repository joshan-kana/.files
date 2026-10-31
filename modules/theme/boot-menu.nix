{ lib, system, ... }:
{
  enable = false;
}
// lib.optionalAttrs (lib.systems.elaborate system).isLinux {
  boot.loader = {
    timeout = lib.mkDefault 3;
    systemd-boot = {
      consoleMode = "auto";
      configurationLimit = 8;
    };
  };
}
