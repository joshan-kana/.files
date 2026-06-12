{
  lib,
  osConfig,
  pkgs,
  ...
}:

lib.mkIf osConfig.dotfiles.features.desktop.enable {
  services.mopidy = {
    enable = false;
    extensionPackages = with pkgs; [
      mopidy-mpd
      mopidy-mpris
    ];
    settings.mpd = {
      enabled = true;
      hostname = "127.0.0.1";
      port = "6600";
    };
  };

  programs.spicetify.enable = true;
}
