{
  editScope,
  extendScope,
  moduleRegistry,
  ...
}:

{
  inherit (moduleRegistry)
    theme
    networking
    backups
    ;

  dotfiles.users.primary.homeRoot = "/Users";

  nix = editScope moduleRegistry.nix {
    builders = { inherited, ... }: {
      # OrbStack runs on this Mac, so use its local SSH port.
      nix.buildMachines = map (
        builder: builder // { hostName = "127.0.0.1:32223"; }
      ) inherited.nix.buildMachines;
    };
  };

  system =
    extendScope
      (editScope moduleRegistry.system {
        identity = _: {
          # DHCP registers this LAN target, leaving mac.home to the failover record.
          networking.hostName = "joshans-macbook-pro";
        };

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

        homebrew = _: {
          homebrew = {
            enable = true;
            onActivation.cleanup = "none";
          };
        };

        gstreamerRuntime = _: {
          homebrew.casks = [ "gstreamer-runtime" ];
        };

        gzRendering8 = _: {
          homebrew = {
            brews = [ "osrf/simulation/gz-rendering8" ];
            taps = [
              "osrf/simulation"
            ];
          };
        };

        moltenVk = _: {
          homebrew.brews = [ "molten-vk" ];
        };

        qt5 = _: {
          homebrew.brews = [ "qt@5" ];
        };

        speexdsp = _: {
          homebrew.brews = [ "speexdsp" ];
        };

        vulkanLoader = _: {
          homebrew.brews = [ "vulkan-loader" ];
        };

        zlib = _: {
          homebrew.brews = [ "zlib" ];
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

    blockGooseCli = _: {
      homebrew.brews = [ "block-goose-cli" ];
    };

    cocoaWay = _: {
      homebrew = {
        brews = [ "j-x-z/tap/cocoa-way" ];
        taps = [
          "j-x-z/tap"
        ];
      };
    };

    crush = _: {
      homebrew = {
        brews = [ "charmbracelet/tap/crush" ];
        taps = [
          "charmbracelet/tap"
        ];
      };
    };

    peekaboo = _: {
      homebrew = {
        brews = [ "steipete/tap/peekaboo" ];
        taps = [
          "steipete/tap"
        ];
      };
    };

    piCodingAgent = _: {
      homebrew.brews = [ "pi-coding-agent" ];
    };

    qmk = _: {
      homebrew = {
        brews = [ "qmk/qmk/qmk" ];
        taps = [
          "qmk/qmk"
          "osx-cross/arm"
          "osx-cross/avr"
        ];
      };
    };

    rust = _: {
      homebrew.brews = [ "rust" ];
    };

    sessionwiki = _: {
      homebrew = {
        brews = [ "youdie006/tap/sessionwiki" ];
        taps = [
          "youdie006/tap"
        ];
      };
    };

    waypipeDarwin = _: {
      homebrew.brews = [ "j-x-z/tap/waypipe-darwin" ];
    };
  };

  desktop = extendScope moduleRegistry.desktop {
    hammerspoon = import ../../modules/desktop/hammerspoon;
    karabinerElements = _: {
      # Karabiner 15+ uses SMAppService; the nix-darwin service still
      # installs LaunchAgents from the removed pre-15 package layout.
      homebrew.casks = [ "karabiner-elements" ];
    };
    raycast = _: {
      homebrew.casks = [ "raycast" ];
    };
    yabai = import ../../modules/desktop/yabai;

    aldente = _: {
      homebrew.casks = [ "aldente" ];
    };

    homerow = _: {
      homebrew.casks = [ "homerow" ];
    };

    jordanbairdIce = _: {
      homebrew.casks = [ "jordanbaird-ice" ];
    };

    linearmouse = _: {
      homebrew.casks = [ "linearmouse" ];
    };

    logiOptions = _: {
      homebrew.casks = [ "logi-options+" ];
    };

    xquartz = _: {
      homebrew.casks = [ "xquartz" ];
    };
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

    cardinal = _: {
      homebrew.casks = [ "cardinal" ];
    };

    chatgpt = { pkgs, ... }: {
      environment.systemPackages = [ pkgs.chatgpt-mac ];
    };

    codexApp = _: {
      homebrew.casks = [ "codex-app" ];
    };

    googleChrome = _: {
      homebrew.casks = [ "google-chrome" ];
    };

    ilokLicenseManager = _: {
      homebrew.casks = [ "ilok-license-manager" ];
    };

    iterm2 = { pkgs, ... }: {
      environment.systemPackages = [ pkgs.iterm2-mac ];
    };

    izotopeProductPortal = _: {
      homebrew.casks = [ "izotope-product-portal" ];
    };

    kicad = _: {
      homebrew.casks = [ "kicad" ];
    };

    krita = _: {
      homebrew.casks = [ "krita" ];
    };

    microsoftAutoUpdate = _: {
      homebrew.casks = [ "microsoft-auto-update" ];
    };

    microsoftOffice = _: {
      homebrew.casks = [ "microsoft-office" ];
    };

    microsoftTeams = _: {
      homebrew.casks = [ "microsoft-teams" ];
    };

    nativeAccess = _: {
      homebrew.casks = [ "native-access" ];
    };

    nvidiaGeforceNow = _: {
      homebrew.casks = [ "nvidia-geforce-now" ];
    };

    openWebui = { pkgs, ... }: {
      environment.systemPackages = [ pkgs.open-webui-mac ];
    };

    openclaw = _: {
      homebrew.casks = [ "openclaw" ];
    };

    orcaSlicerNightly = _: {
      homebrew.casks = [ "orcaslicer@nightly" ];
    };

    parsec = _: {
      homebrew.casks = [ "parsec" ];
    };

    softubeCentral = _: {
      homebrew.casks = [ "softube-central" ];
    };

    steam = _: {
      homebrew.casks = [ "steam" ];
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

    utm = _: {
      homebrew.casks = [ "utm@beta" ];
    };
  };
}
