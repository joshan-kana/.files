{
  config,
  lib,
  pkgs,
  system,
  ...
}:

let
  inherit (lib.systems.elaborate system) isDarwin isLinux isx86_64;
in
{
  home =
    _:
    lib.optionalAttrs isLinux {
      xdg.mimeApps = {
        enable = true;
        defaultApplications = lib.genAttrs [
          "text/html"
          "application/xhtml+xml"
          "x-scheme-handler/http"
          "x-scheme-handler/https"
        ] (_: "${config.dotfiles.defaults.browser}.desktop");
      };
      home.sessionVariables.BROWSER = config.dotfiles.defaults.browser;
    };

  brave = _: {
    home = _: {
      home.packages = [ pkgs.brave ];
    };
  };

  neodisk = _: {
    home = _: {
      home.packages = [ pkgs.neodisk ];
    };
  };

  bitwarden = _: {
    home = _: {
      home.packages = [ pkgs.bitwarden-desktop ];
    };
  };

  warp = _: {
    home = _: { home.packages = [ pkgs.warp-terminal ]; };
  };

  mullvad =
    _:
    lib.optionalAttrs isLinux {
      environment.systemPackages = [ pkgs.mullvad-vpn ];
      services.mullvad-vpn.enable = true;
    }
    // lib.optionalAttrs isDarwin {
      homebrew.casks = [ "mullvad-vpn" ];
    };

  chromium =
    _:
    lib.optionalAttrs isLinux {
      home = _: { home.packages = [ pkgs.chromium ]; };
    };

  zen = _: {
    home = _: {
      programs.zen-browser.enable = true;
    };

  firefox =
    _:
    let
      disableSafeModeKey = "1";
    in
    {
      home =
        _:
        {
          # Keep the startup modifier override available to shell-launched browsers.
          home.sessionVariables.MOZ_DISABLE_SAFE_MODE_KEY = disableSafeModeKey;
          programs.firefox =
            lib.optionalAttrs isDarwin {
              package = pkgs.firefox-bin;
              configPath = "Library/Application Support/Firefox";
            }
            // lib.optionalAttrs isLinux {
              configPath = ".mozilla/firefox";
            };
        }
        // lib.optionalAttrs isDarwin {
          # The graphical login environment does not inherit shell variables.
          launchd.agents.disableFirefoxSafeModeKey = {
            enable = true;
            config = {
              Label = "com.joshankana.disable-firefox-safe-mode-key";
              ProgramArguments = [
                "/bin/launchctl"
                "setenv"
                "MOZ_DISABLE_SAFE_MODE_KEY"
                disableSafeModeKey
              ];
              RunAtLoad = true;
            };
          };
        };
    }
    // lib.optionalAttrs isLinux {
      # Set the variable for graphical sessions launched by the display manager.
      environment.sessionVariables.MOZ_DISABLE_SAFE_MODE_KEY = disableSafeModeKey;
    };

  floorp = _: { };

  kitty = _: {
    home = _: {
      programs.kitty = {
        enable = true;
        settings = {
          confirm_os_window_close = 0;
          enable_audio_bell = false;
          input_delay = 0;
          touch_scroll_multiplier = 3.0;
          cursor_trail = 1;
          cursor_trail_decay = "0.16 0.16";
          cursor_trail_start_threshold = "0 0";
          remember_window_size = false;
        };
      };
    };
  };

  alacritty = _: {
    home = _: {
      programs.alacritty = { };
    };
  };

  thunderbird = _: {
    home = _: {
      home.packages = [ (if isDarwin then pkgs.thunderbird-bin else pkgs.thunderbird) ];
    };
  };

  obsidian = _: {
    home = _: {
      home.packages = [ pkgs.obsidian ];
    };
  };

  gimp = _: {
    home = _: { home.packages = [ pkgs.gimp ]; };
  };

  githubDesktop = _: {
    home =
      _:
      lib.optionalAttrs isLinux {
        home.packages = [ pkgs.github-desktop ];
      };
  };

  vscode = _: {
    home = _: {
      programs.vscode.profiles.default.userSettings = { };
    };
  };

  pycharm = _: {
    home = _: {
      home.packages = [ pkgs.jetbrains.pycharm ];
    };
  };

  squirreldisk = _: {
    home = _: {
      home.packages = [ pkgs.squirreldisk ];
    };
  };

  libreoffice = _: {
    home = _: { home.packages = [ pkgs.libreoffice ]; };
  };

  sunshine =
    _:
    {
      environment.systemPackages = [ pkgs.sunshine ];
    }
    // lib.optionalAttrs isLinux {
      networking.firewall.allowedTCPPorts = [ 47990 ];
    };

  moonlight = _: {
    home = _: {
      home.packages = [ pkgs.moonlight-qt ];
    };
  };

  jellyfin =
    _:
    let
      settings = {
        hwdec = "auto";
        network_buffer = "default";
        segment_commercial = "ask";
        segment_preview = "ask";
        segment_recap = "ask";
        theme = "superdark";
      };
    in
    {
      home =
        {
          config,
          lib,
          pkgs,
          ...
        }:
        {
          home = {
            packages = [ pkgs.jellyfin-mpv-shim ];
            shellAliases.jm = "jellyfin-mpv-shim";
          }
          // lib.optionalAttrs isDarwin {
            file."Library/Application Support/jellyfin-mpv-shim/mpv.conf".source =
              config.xdg.configFile."mpv/mpv.conf".source;
            activation.jellyfinMpvShimSettings = lib.hm.dag.entryAfter [ "linkGeneration" ] (
              lib.hm.generators.mkImpureConfigMerger {
                inherit pkgs;
                format = "json";
                empty = "{}";
                jqOperation = "$dynamic * $static";
                path = "${config.home.homeDirectory}/Library/Application Support/jellyfin-mpv-shim/conf.json";
                staticSettings = (pkgs.formats.json { }).generate "jellyfin-mpv-shim-settings" settings;
              }
            );
          };
        }
        // lib.optionalAttrs isLinux {
          services.jellyfin-mpv-shim = {
            enable = true;
            inherit settings;
          };
          systemd.user.services.jellyfin-mpv-shim.Install.WantedBy = lib.mkForce [ ];
          xdg.configFile."jellyfin-mpv-shim/mpv.conf".source = config.xdg.configFile."mpv/mpv.conf".source;
        };
    }
    // lib.optionalAttrs isDarwin {
      launchd.user.agents.jellyfin-mpv-shim.serviceConfig = {
        ProgramArguments = [ (lib.getExe pkgs.jellyfin-mpv-shim) ];
        EnvironmentVariables.PATH = "${lib.makeBinPath [ pkgs.mpv ]}:/usr/bin:/bin";
        RunAtLoad = false;
      };
    };

  vlc = _: {
    home = _: { home.packages = [ pkgs.vlc ]; };
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

  ollama =
    _:
    (
      lib.optionalAttrs isLinux {
        networking.firewall.allowedTCPPorts = [
          11434
          11435
        ];
      }
      // lib.optionalAttrs isDarwin {
        home = _: { home.packages = [ pkgs.ollama ]; };
        launchd.user.agents.ollama.serviceConfig = {
          ProgramArguments = [
            (lib.getExe pkgs.ollama)
            "serve"
          ];
          RunAtLoad = true;
          KeepAlive = true;
          # Preserve the previous IPv4/IPv6 LAN listener.
          EnvironmentVariables.OLLAMA_HOST = "[::]:11434";
        };
      }
    );

  spotify =
    { lib, options, ... }:
    (lib.optionalAttrs isLinux (
      lib.optionalAttrs (lib.hasAttrByPath [ "programs" "spicetify" ] options) {
        programs.spicetify.enable = true;
      }
    ))
    // lib.optionalAttrs isDarwin {
      # The pinned Darwin Nixpkgs source depends on a stalled Wayback download.
      homebrew.casks = [ "spotify" ];
    };

  discord = _: {
    home = _: {
      home.packages = [ pkgs.discord ];
    };
  };

  dropbox = _: {
    home = _: { home.packages = [ pkgs.dropbox ]; };
  };

  onlyoffice = _: {
    home =
      _:
      lib.optionalAttrs isLinux {
        home.packages = [ pkgs.onlyoffice-desktopeditors ];
      };
  };

  twingate =
    _:
    lib.optionalAttrs isLinux {
      services.twingate.enable = true;
    };

  beeperMatrixClient = _: {
    home = _: {
      home.packages = [ pkgs.beeper ];
    };
  };

  chatgpt = _: {
    home = _: { home.packages = [ pkgs.chatgpt ]; };
  };

  bambuStudio = { pkgs, ... }: {
    home = _: { home.packages = [ pkgs.bambu-studio ]; };
  };

  coolRetroTerm = { pkgs, ... }: {
    home = _: { home.packages = [ pkgs.cool-retro-term ]; };
  };

  googleChrome = { pkgs, ... }: {
    home = _: { home.packages = [ pkgs.google-chrome ]; };
  };

  inkscape = { pkgs, ... }: {
    home = _: { home.packages = [ pkgs.inkscape ]; };
  };

  krita = { pkgs, ... }: {
    home = _: { home.packages = [ pkgs.krita ]; };
  };

  prusaSlicer = { pkgs, ... }: {
    home = _: { home.packages = [ pkgs.prusa-slicer ]; };
  };

  qbittorrent = { pkgs, ... }: {
    home = _: { home.packages = [ pkgs.qbittorrent ]; };
  };

  zed = { pkgs, ... }: {
    home = _: { home.packages = [ pkgs.zed-editor ]; };
  };

  filelight =
    _:
    lib.optionalAttrs isLinux {
      home = _: { home.packages = [ pkgs.kdePackages.filelight ]; };
    };
  gparted =
    _:
    lib.optionalAttrs isLinux {
      home = _: { home.packages = [ pkgs.gparted ]; };
    };
  nautilus =
    _:
    lib.optionalAttrs isLinux {
      home = _: { home.packages = [ pkgs.nautilus ]; };
    };
  waypipe =
    _:
    lib.optionalAttrs isLinux {
      home = _: { home.packages = [ pkgs.waypipe ]; };
    };

  arc =
    { pkgs, ... }:
    lib.optionalAttrs isDarwin {
      home = _: { home.packages = [ pkgs.arc ]; };
    };

  cryptomator = { pkgs, ... }: {
    home = _: { home.packages = [ pkgs.cryptomator ]; };
  };

  ghostty = { pkgs, ... }: {
    home = _: {
      home.packages = [ (if isDarwin then pkgs.ghostty-bin else pkgs.ghostty) ];
    };
  };

  linear =
    { pkgs, ... }:
    lib.optionalAttrs isDarwin {
      home = _: { home.packages = [ pkgs.linear ]; };
    };

  iterm2 =
    { pkgs, ... }:
    lib.optionalAttrs isDarwin {
      home = _: { home.packages = [ pkgs.iterm2 ]; };
    };

  microsoftOfficeSuite =
    _:
    lib.optionalAttrs isDarwin {
      homebrew.casks = [
        "microsoft-auto-update"
        "microsoft-office"
        "microsoft-teams"
      ];
    };

  nvidiaGeforceNow =
    _:
    lib.optionalAttrs isDarwin {
      homebrew.casks = [ "nvidia-geforce-now" ];
    };

  openWebui = { pkgs, ... }: {
    home = _: { home.packages = [ pkgs.open-webui-desktop ]; };
  };

  openclaw =
    _:
    lib.optionalAttrs isDarwin {
      homebrew.casks = [ "openclaw" ];
    };

  orcaSlicerNightly =
    _:
    lib.optionalAttrs isDarwin {
      homebrew.casks = [ "orcaslicer@nightly" ];
    };

  vial =
    { pkgs, ... }:
    lib.optionalAttrs isDarwin {
      home = _: { home.packages = [ pkgs.vial ]; };
    };

  keymapp =
    { pkgs, ... }:
    lib.optionalAttrs (isDarwin || (isLinux && isx86_64)) {
      home = _: {
        home.packages = [ pkgs.keymapp ];
      };
    };
}
