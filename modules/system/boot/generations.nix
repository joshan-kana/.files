{
  lib,
  system,
  ...
}:
let
  configurationLimit = 10;
in
lib.optionalAttrs (lib.systems.elaborate system).isLinux {
  boot.loader = {
    generic-extlinux-compatible.configurationLimit = configurationLimit;
    grub.configurationLimit = configurationLimit;
    systemd-boot.configurationLimit = configurationLimit;
  };
}
