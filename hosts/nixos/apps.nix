{ pkgs, ... }:

{
  brave = _: {
    environment.systemPackages = [ pkgs.brave ];
  };

  spotify = _: {
    environment.systemPackages = [ pkgs.spotify ];

    home = _: {
      programs.spicetify.enable = true;
    };
  };

  bitwarden = _: {
    environment.systemPackages = [ pkgs.bitwarden-desktop ];
  };

  discord = _: {
    environment.systemPackages = [ pkgs.discord ];
  };

  dropbox = _: {
    environment.systemPackages = [ pkgs.dropbox ];
  };

  warp = _: {
    environment.systemPackages = [ pkgs.warp-terminal ];
  };

  onlyoffice = _: {
    environment.systemPackages = [ pkgs.onlyoffice-desktopeditors ];
  };
}
