{
  lib,
  system,
  ...
}:

lib.optionalAttrs (lib.systems.elaborate system).isLinux {
  boot.loader = {
    generic-extlinux-compatible.configurationLimit = lib.mkDefault 10;
    grub.configurationLimit = lib.mkDefault 10;
    systemd-boot.configurationLimit = lib.mkDefault 10;
  };
}
