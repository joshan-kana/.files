{
  editScope,
  lib,
  moduleRegistry,
}:

lib.recursiveUpdate (import ./minimal.nix { inherit lib moduleRegistry; }) {
  inherit (moduleRegistry) audio desktop;

  desktopApps = editScope moduleRegistry.desktopApps {
    jellyfin = _: {
      home = _: {
        systemd.user.services.jellyfin-mpv-shim.Install.WantedBy = lib.mkForce [
          "graphical-session.target"
        ];
      };
    };
  };

  dotfiles = {
    defaults.browser = {
      command = "chromium";
      desktopId = "chromium-browser.desktop";
    };
    scopes = {
      virtualisation.enable = false;
      desktop = {
        children.enable = false;
        mediaSession.enable = true;
      };
      desktopApps = {
        children.enable = false;
        chromium.enable = true;
        jellyfin.enable = true;
        kdeConnect.enable = true;
        kodi.enable = true;
        librespot.enable = true;
        moonlight.enable = true;
        mullvad.enable = true;
      };
    };
  };
}
