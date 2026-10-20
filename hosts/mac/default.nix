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

      };

  cli = extendScope moduleRegistry.cli {
    bitwardenCli = { pkgs, ... }: {
      environment.systemPackages = [ pkgs.bitwarden-cli ];
    };

    esptool = { pkgs, ... }: {
      environment.systemPackages = [ pkgs.esptool ];
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

    blockGooseCli = _: {
      homebrew.brews = [ "block-goose-cli" ];
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

    microsoftOfficeSuite = _: {
      homebrew.casks = [
        "microsoft-auto-update"
        "microsoft-office"
        "microsoft-teams"
      ];
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
