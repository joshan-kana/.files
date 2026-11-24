{
  lib,
  system,
  ...
}:

let
  inherit (lib.systems.elaborate system) isLinux;
in
{
  enable = isLinux;

  config = lib.optionalAttrs isLinux {
    boot.loader = {
      systemd-boot.enable = true;
      efi.canTouchEfiVariables = true;
    };
  };
}
