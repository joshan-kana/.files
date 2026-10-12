{
  macHomebrew = { lib, system, ... }: {
    # Keep the remaining native casks without deleting existing installations.
    config = lib.optionalAttrs (lib.systems.elaborate system).isDarwin {
      homebrew = {
        enable = true;
        onActivation.cleanup = "none";
      };
    };
    home = { lib, ... }: {
      programs.zsh.profileExtra = lib.mkBefore ''
        if [[ -x /opt/homebrew/bin/brew ]]; then
          eval "$(/opt/homebrew/bin/brew shellenv)"
        fi
      '';
    };
  };

  qmkToolbox = { pkgs, ... }: {
    environment.systemPackages = [ pkgs.qmk-toolbox-mac ];
  };

  arc = { pkgs, ... }: {
    environment.systemPackages = [ pkgs.arc-mac ];
  };

  bambuStudio = { pkgs, ... }: {
    environment.systemPackages = [ pkgs.bambu-studio ];
  };

  arduinoIde = { pkgs, ... }: {
    environment.systemPackages = [ pkgs.arduino-ide-mac ];
  };

  cryptomator = { pkgs, ... }: {
    environment.systemPackages = [ pkgs.cryptomator-mac ];
  };

  raspberryPiImager = { pkgs, ... }: {
    environment.systemPackages = [ pkgs.raspberry-pi-imager-mac ];
  };

  heroic = { pkgs, ... }: {
    environment.systemPackages = [ pkgs.heroic-mac ];
  };

  vial = { pkgs, ... }: {
    environment.systemPackages = [ pkgs.vial-mac ];
  };

  ghostty = { pkgs, ... }: {
    environment.systemPackages = [ pkgs.ghostty-bin ];
  };

  notion = { pkgs, ... }: {
    environment.systemPackages = [ pkgs.notion-mac ];
  };

  coolRetroTerm = { pkgs, ... }: {
    environment.systemPackages = [ pkgs.cool-retro-term ];
  };

  dolphinEmulator = { pkgs, ... }: {
    environment.systemPackages = [ pkgs.dolphin-emu ];
  };

  inkscape = { pkgs, ... }: {
    environment.systemPackages = [ pkgs.inkscape ];
  };

  linear = { pkgs, ... }: {
    environment.systemPackages = [ pkgs.linear-mac ];
  };

  prusaSlicer = { pkgs, ... }: {
    environment.systemPackages = [ pkgs.prusa-slicer ];
  };

  qbittorrent = { pkgs, ... }: {
    environment.systemPackages = [ pkgs.qbittorrent ];
  };

  reaper = { pkgs, ... }: {
    environment.systemPackages = [ pkgs.reaper-mac ];
  };

  zed = { pkgs, ... }: {
    environment.systemPackages = [ pkgs.zed-editor ];
  };
}
