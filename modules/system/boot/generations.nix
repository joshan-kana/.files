{
  lib,
  system,
  ...
}:

lib.optionalAttrs (lib.systems.elaborate system).isLinux {
  boot.loader = {
    generic-extlinux-compatible.configurationLimit = 10;
    grub.configurationLimit = 10;
    systemd-boot.configurationLimit = 10;
  };
}
