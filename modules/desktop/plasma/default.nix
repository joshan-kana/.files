{
  config,
  inputs,
  lib,
  ...
}:

let
  terminal = config.dotfiles.defaults.terminal;
  aliases.k = "startplasma-wayland";
in
{
  environment.shellAliases = aliases;
  services.desktopManager.plasma6.enable = true;
  environment.sessionVariables.KWIN_FORCE_SW_CURSOR = "1";

  home = _: {
    imports = [
      inputs.plasma-manager.homeModules.plasma-manager
      ./generated.nix
    ];

    home.shellAliases = aliases;
    programs.plasma = {
      enable = true;
      configFile.kdeglobals.General = {
        TerminalApplication = lib.mkForce terminal;
        TerminalService = lib.mkForce "${terminal}.desktop";
      };
    };
  };
}
