{
  editScope,
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

  system =
    extendScope
      (editScope moduleRegistry.system {
        autoDeploy = _: {
          # OrbStack occupies port 4243 on this Mac.
          services.comin.exporter = {
            listen_address = "127.0.0.1";
            port = 4244;
          };
        };
      })
      {
        authentication = _: {
          security.pam.services.sudo_local.touchIdAuth = true;
        };

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
      # Karabiner 15+ uses SMAppService; the nix-darwin service still
      # installs LaunchAgents from the removed pre-15 package layout.
      homebrew.casks = [ "karabiner-elements" ];
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
        # Keep remaining vendor and specialist packages declarative while
        # migrating supported applications to native Nix packages.
        taps = [
          "charmbracelet/tap"
          "esengine/reasonix"
          "italomandara/cxpatcher"
          "j-x-z/tap"
          "osrf/simulation"
          "qmk/qmk"
          "steipete/tap"
          "youdie006/tap"
        ];
        brews = [
          "block-goose-cli"
          "charmbracelet/tap/crush"
          "j-x-z/tap/cocoa-way"
          "j-x-z/tap/waypipe-darwin"
          "molten-vk"
          "ollama"
          "osrf/simulation/gz-rendering8"
          "pi-coding-agent"
          "qmk/qmk/qmk"
          "qt@5"
          "rust"
          "speexdsp"
          "steipete/tap/peekaboo"
          "vulkan-loader"
          "youdie006/tap/sessionwiki"
          "zlib"
        ];
        casks = [
          "aldente"
          "cardinal"
          "chatgpt"
          "codex-app"
          "cryptomator"
          "google-chrome"
          "gstreamer-runtime"
          "hammerspoon"
          "homerow"
          "ilok-license-manager"
          "inkscape"
          "iterm2"
          "izotope-product-portal"
          "jordanbaird-ice"
          "kicad"
          "krita"
          "libreoffice"
          "linearmouse"
          "logi-options+"
          "microsoft-auto-update"
          "microsoft-office"
          "microsoft-teams"
          "mullvad-vpn"
          "native-access"
          "nvidia-geforce-now"
          "open-webui"
          "openclaw"
          "orcaslicer@nightly"
          "parsec"
          "raycast"
          "softube-central"
          "steam"
          "tailscale-app"
          "utm@beta"
          "vlc"
          "warp"
          "xquartz"
        ];
      };
      home = { lib, ... }: {
        programs.zsh.profileExtra = lib.mkBefore ''
          if [[ -x /opt/homebrew/bin/brew ]]; then
            eval "$(/opt/homebrew/bin/brew shellenv)"
            # Prefer declaratively managed tools while Homebrew remains in use.
            typeset -U path
            path=(
              "$HOME/.local/bin"
              "/etc/profiles/per-user/$USER/bin"
              "/run/current-system/sw/bin"
              "$HOME/.nix-profile/bin"
              "''${path[@]}"
            )
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
    orbStack = { pkgs, ... }: {
      environment.systemPackages = [ pkgs.orbstack ];
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
