{ moduleRegistry }:
{
  inherit (moduleRegistry)
    system
    nix
    theme
    cli
    networking
    appimage
    audio
    virtualisation
    desktop
    desktopApps
    backups
    ;
  dotfiles.scopes.desktop.gnome.enable = false;
}
