{ lib, system, ... }:

lib.optionalAttrs (lib.systems.elaborate system).isLinux {
  security = {
    run0 = {
      enable = true;
      persistentAuth.enable = true;
    };
    sudo.enable = false;
    sudo-rs.enable = false;
    doas.enable = false;
    please.enable = false;
    polkit.enablePkexecWrapper = false;
    wrappers.su.enable = false;
  };
}
