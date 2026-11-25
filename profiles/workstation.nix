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
  dotfiles.scopes = {
    desktop = {
      gnome.enable = false;
      mediaSession.enable = false;
    };
    desktopApps = {
      kdeConnect.enable = false;
      kodi.enable = false;
      librespot.enable = false;
    };
  };
}
