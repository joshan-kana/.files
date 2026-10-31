{
  lib,
  pkgs,
  system,
  ...
}:

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
    polkit = {
      enablePkexecWrapper = false;
      package = pkgs.polkitWithHybridCgroup;
    };
    wrappers.su.enable = false;
  };
  home = _: {
    home.shellAliases.run0 = "run0 ";
  };
}
