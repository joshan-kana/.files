{ config, pkgs, spicetify-nix, ... }:
{
  # Mopidy (MPD)
  services.mopidy = {
    enable = false;
    extensionPackages = with pkgs; [
      mopidy-mpd
      mopidy-mpris
    ];
    settings = {
      mpd = {
        enabled = true;
        hostname = "127.0.0.1";
        port = "6600";
      };
    };
  };

  # spicetify
  programs.spicetify = {
    enable = true;
  };
}
