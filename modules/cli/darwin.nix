{
  automake = { pkgs, ... }: {
    environment.systemPackages = [ pkgs.automake ];
  };

  bitwardenCli = { pkgs, ... }: {
    environment.systemPackages = [ pkgs.bitwarden-cli ];
  };

  ccache = { pkgs, ... }: {
    environment.systemPackages = [ pkgs.ccache ];
  };

  esptool = { pkgs, ... }: {
    environment.systemPackages = [ pkgs.esptool ];
  };

  fio = { pkgs, ... }: {
    environment.systemPackages = [ pkgs.fio ];
  };

  glslang = { pkgs, ... }: {
    environment.systemPackages = [ pkgs.glslang ];
  };

  mas = { pkgs, ... }: {
    environment.systemPackages = [ pkgs.mas ];
  };

  mediainfo = { pkgs, ... }: {
    environment.systemPackages = [ pkgs.mediainfo ];
  };

  ninja = { pkgs, ... }: {
    environment.systemPackages = [ pkgs.ninja ];
  };

  sevenzip = { pkgs, ... }: {
    environment.systemPackages = [ pkgs._7zz ];
  };

  spicetify = { pkgs, ... }: {
    environment.systemPackages = [ pkgs.spicetify-cli ];
  };

  tio = { pkgs, ... }: {
    environment.systemPackages = [ pkgs.tio ];
  };

  uv = { pkgs, ... }: {
    environment.systemPackages = [ pkgs.uv ];
  };

}
