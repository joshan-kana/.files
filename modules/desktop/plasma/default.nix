{ inputs, ... }: {
  services.desktopManager.plasma6.enable = true;
  environment.sessionVariables.KWIN_FORCE_SW_CURSOR = "1";

  home = _: {
    imports = [
      inputs.plasma-manager.homeModules.plasma-manager
      ./generated.nix
    ];

    programs.plasma.enable = true;
    programs.zsh.shellAliases.k = "startplasma-wayland";
  };
}
