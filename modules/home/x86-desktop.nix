{
  lib,
  osConfig,
  ...
}:

lib.mkIf osConfig.dotfiles.features.desktop.enable {
  programs.spicetify.enable = true;
}
