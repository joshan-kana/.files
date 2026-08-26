{ pkgs, ... }:

{
  sunshine = _: {
    environment.systemPackages = [ pkgs.sunshine ];
    networking.firewall.allowedTCPPorts = [ 47990 ];
  };

  moonlight = _: {
    environment.systemPackages = [ pkgs.moonlight-qt ];
  };

  waypipe = _: {
    environment.systemPackages = [ pkgs.waypipe ];
  };

  vlc = _: {
    environment.systemPackages = [ pkgs.vlc ];
  };

  mopidy = _: {
    home = _: {
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
    };
  };
}
