{
  lib,
  moduleRegistry,
}:

lib.recursiveUpdate (import ./minimal.nix { inherit lib moduleRegistry; }) {
  inherit (moduleRegistry) audio desktop desktopApps;

  dotfiles = {
    defaults.browser = "chromium";
    scopes = {
      cli.mpv.enable = true;
      virtualisation.enable = false;
      desktop = {
        children.enable = false;
        mediaSession.enable = true;
      };
      desktopApps = {
        children.enable = false;
        chromium.enable = true;
        jellyfin.enable = true;
        kdeconnect.enable = true;
        kodi.enable = true;
        librespot.enable = true;
        moonlight.enable = true;
        mullvad.enable = true;
      };
    };
  };
}
