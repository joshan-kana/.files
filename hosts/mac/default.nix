{
  extendScope,
  moduleRegistry,
  ...
}:

{
  inherit (moduleRegistry)
    nix
    theme
    networking
    backups
    ;

  dotfiles.users.primary.homeRoot = "/Users";

  system = extendScope moduleRegistry.system {
    preferences = _: {
      system.defaults = {
        dock = {
          autohide = true;
          show-recents = false;
          tilesize = 47;
          mru-spaces = false;
        };
        NSGlobalDomain = {
          KeyRepeat = 2;
          InitialKeyRepeat = 15;
        };
      };
    };
  };

  cli = extendScope moduleRegistry.cli {
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

    macShell = _: {
      home = { lib, ... }: {
        home = {
          sessionPath = [ "$HOME/.local/bin" ];
          shellAliases = {
            caf = "caffeinate -dims";
            sn = "ssh nixos-server";
            pvm = "ssh nixos-arm-parallels";
          };
        };
        programs.zsh.initContent = lib.mkAfter ''
          zd() {
            zip -qry /tmp/upload.zip . && osascript -e 'set the clipboard to POSIX file "/tmp/upload.zip"'
          }
        '';
      };
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

    nixd = { pkgs, ... }: {
      environment.systemPackages = [ pkgs.nixd ];
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
  };

  desktop = extendScope moduleRegistry.desktop {
    hammerspoon = import ../../modules/desktop/hammerspoon;
    karabinerElements = _: {
      services.karabiner-elements.enable = true;
    };
    raycast = { pkgs, ... }: {
      environment.systemPackages = [ pkgs.raycast ];
    };
    yabai = import ../../modules/desktop/yabai;
  };

  desktopApps = extendScope moduleRegistry.desktopApps {
    arc = { pkgs, ... }: {
      environment.systemPackages = [ pkgs.arc-mac ];
    };

    arduinoIde = { pkgs, ... }: {
      environment.systemPackages = [ pkgs.arduino-ide-mac ];
    };

    bambuStudio = { pkgs, ... }: {
      environment.systemPackages = [ pkgs.bambu-studio ];
    };

    coolRetroTerm = { pkgs, ... }: {
      environment.systemPackages = [ pkgs.cool-retro-term ];
    };

    cryptomator = { pkgs, ... }: {
      environment.systemPackages = [ pkgs.cryptomator-mac ];
    };

    dolphinEmulator = { pkgs, ... }: {
      environment.systemPackages = [ pkgs.dolphin-emu ];
    };

    ghostty = { pkgs, ... }: {
      environment.systemPackages = [ pkgs.ghostty-bin ];
    };

    heroic = { pkgs, ... }: {
      environment.systemPackages = [ pkgs.heroic-mac ];
    };

    inkscape = { pkgs, ... }: {
      environment.systemPackages = [ pkgs.inkscape ];
    };

    linear = { pkgs, ... }: {
      environment.systemPackages = [ pkgs.linear-mac ];
    };

    macHomebrew = _: {
      homebrew = {
        enable = true;
        onActivation.cleanup = "none";
      };
      home = { lib, ... }: {
        programs.zsh.profileExtra = lib.mkBefore ''
          if [[ -x /opt/homebrew/bin/brew ]]; then
            eval "$(/opt/homebrew/bin/brew shellenv)"
          fi
        '';
      };
    };

    notion = { pkgs, ... }: {
      environment.systemPackages = [ pkgs.notion-mac ];
    };

    prusaSlicer = { pkgs, ... }: {
      environment.systemPackages = [ pkgs.prusa-slicer ];
    };

    qbittorrent = { pkgs, ... }: {
      environment.systemPackages = [ pkgs.qbittorrent ];
    };

    qmkToolbox = { pkgs, ... }: {
      environment.systemPackages = [ pkgs.qmk-toolbox-mac ];
    };

    raspberryPiImager = { pkgs, ... }: {
      environment.systemPackages = [ pkgs.raspberry-pi-imager-mac ];
    };

    reaper = { pkgs, ... }: {
      environment.systemPackages = [ pkgs.reaper-mac ];
    };

    vial = { pkgs, ... }: {
      environment.systemPackages = [ pkgs.vial-mac ];
    };

    zed = { pkgs, ... }: {
      environment.systemPackages = [ pkgs.zed-editor ];
    };
  };

  virtualisation = extendScope moduleRegistry.virtualisation {
    orbStack = _: {
      home = _: {
        home.shellAliases.o = "orb";
        programs.zsh.profileExtra = ''
          if [[ -f "$HOME/.orbstack/shell/init.zsh" ]]; then
            source "$HOME/.orbstack/shell/init.zsh"
          fi
        '';
      };
    };
  };
}
