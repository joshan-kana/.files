_: {
  services.desktopManager.plasma6.enable = true;

  home = _: {
    imports = [ ./generated.nix ];

    programs.plasma.enable = true;
    programs.zsh.shellAliases.k = "startplasma-wayland";
  };
}
