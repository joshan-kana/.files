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
    xdg.dataFile."applications/dotfiles-terminal.desktop".text = ''
      [Desktop Entry]
      Type=Application
      Name=Default Terminal
      Exec=${terminal}
      Icon=utilities-terminal
      Terminal=false
      NoDisplay=true
      Categories=System;TerminalEmulator;
    '';

    imports = [
      inputs.plasma-manager.homeModules.plasma-manager
      ./generated.nix
    ];

    home.shellAliases.k = "startplasma-wayland";
    programs.plasma = {
      enable = true;
      configFile.kdeglobals.General = {
        TerminalApplication = lib.mkForce terminal;
        TerminalService = lib.mkForce "dotfiles-terminal.desktop";
      };
    };
  };
}
