{
  config,
  inputs,
  lib,
  ...
}:

let
  terminal = config.dotfiles.defaults.terminal;
in
{
  services.desktopManager.plasma6.enable = true;
  environment.sessionVariables.KWIN_FORCE_SW_CURSOR = "1";

  home = _: {
    imports = [
      inputs.plasma-manager.homeModules.plasma-manager
      ./generated.nix
    ];

    home.shellAliases.k = "startplasma-wayland";
    programs.plasma = {
      enable = true;
      configFile.kdeglobals.General = {
        TerminalApplication = lib.mkForce terminal;
        TerminalService = lib.mkForce "${terminal}.desktop";
      };
    };
  };
}
