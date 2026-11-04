{
  config,
  lib,
  pkgs,
  system,
  ...
}:

let
  inherit (lib.systems.elaborate system) isDarwin isLinux;
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
      programs.kitty.extraConfig = ''
        confirm_os_window_close 0
        enable_audio_bell no
        input_delay 0
        touch_scroll_multiplier 3.0
      '';
    };
  };

  contour = _: {
    home =
      { config, ... }:
      {
        programs.contour = {
          enable = true;
          settings = {
            gui_config_locked = true;
            default_profile = "main";
            tab_bar_visibility = "Never";
            renderer.backend = "auto";

            profiles.main = {
              show_title_bar = false;
              wm_class = "contour";
              cursor = {
                shape = "block";
                blinking = false;
              };
              normal_mode.cursor.shape = "block";
              visual_mode.cursor.shape = "block";
              cursor_motion_animation_duration = 75;
              screen_transition = "fade";
              screen_transition_duration = 150;
              smooth_scrolling = true;
              momentum_scrolling = true;
              status_line.display = "none";
              scrollbar.position = "Hidden";
            }
            // lib.optionalAttrs isDarwin {
              shell = lib.getExe pkgs.zsh;
              arguments = [ "-l" ];
            };
          }
          // lib.optionalAttrs isDarwin {
            input_mapping = [
              {
                mods = [ "Super" ];
                key = "A";
                action = "SelectAll";
              }
              {
                mods = [ "Super" ];
                key = "C";
                action = "CopySelection";
              }
              {
                mods = [ "Super" ];
                key = "V";
                action = "PasteClipboard";
              }
              {
                mods = [
                  "Super"
                  "Shift"
                ];
                key = "W";
                action = "CloseTab";
              }
              {
                mods = [ "Super" ];
                key = "LeftArrow";
                action = "SendChars";
                chars = "\\x1b[H";
              }
              {
                mods = [ "Super" ];
                key = "RightArrow";
                action = "SendChars";
                chars = "\\x1b[F";
              }
              {
                mods = [ "Super" ];
                key = "UpArrow";
                action = "ScrollToTop";
              }
              {
                mods = [ "Super" ];
                key = "DownArrow";
                action = "ScrollToBottom";
              }
              {
                mods = [ "Alt" ];
                key = "LeftArrow";
                action = "SendChars";
                chars = "\\x1bb";
              }
              {
                mods = [ "Alt" ];
                key = "RightArrow";
                action = "SendChars";
                chars = "\\x1bf";
              }
            ];
          };
        };

        home.sessionPath = lib.optionals isDarwin [ "${pkgs.ncurses}/bin" ];
        home.sessionVariables = lib.optionalAttrs isDarwin {
          TERMINFO_DIRS = "${pkgs.contour.terminfo}/share/terminfo:${config.home.profileDirectory}/share/terminfo:/usr/share/terminfo";
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
        lib.mkMerge [
          { home.packages = [ pkgs.jellyfin-mpv-shim ]; }
          (lib.optionalAttrs isLinux {
            services.jellyfin-mpv-shim = {
              enable = true;
              inherit settings;
            };
            systemd.user.services.jellyfin-mpv-shim.Install.WantedBy = lib.mkForce [ ];
            xdg.configFile."jellyfin-mpv-shim/mpv.conf".source = config.xdg.configFile."mpv/mpv.conf".source;
          })
          (lib.optionalAttrs isDarwin {
            home.file."Library/Application Support/jellyfin-mpv-shim/mpv.conf".source =
              config.xdg.configFile."mpv/mpv.conf".source;
            home.activation.jellyfinMpvShimSettings = lib.hm.dag.entryAfter [ "linkGeneration" ] (
              lib.hm.generators.mkImpureConfigMerger {
                inherit pkgs;
                format = "json";
                empty = "{}";
                jqOperation = "$dynamic * $static";
                path = "${config.home.homeDirectory}/Library/Application Support/jellyfin-mpv-shim/conf.json";
                staticSettings = (pkgs.formats.json { }).generate "jellyfin-mpv-shim-settings" settings;
              }
            );
          })
        ];
    }
    // lib.optionalAttrs isDarwin {
      launchd.user.agents.jellyfin-mpv-shim.serviceConfig = {
        ProgramArguments = [ (lib.getExe pkgs.jellyfin-mpv-shim) ];
        EnvironmentVariables.PATH = "${lib.makeBinPath [ pkgs.mpv ]}:/usr/bin:/bin";
        RunAtLoad = false;
      };
    };

  vlc =
    _:
    (
      lib.optionalAttrs isLinux {
        home = _: { home.packages = [ pkgs.vlc ]; };
      }
      // lib.optionalAttrs isDarwin {
        homebrew.casks = [ "vlc" ];
      }
    );

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

  dropbox =
    _:
    {
      home =
        _:
        lib.optionalAttrs isLinux {
          home.packages = [ pkgs.dropbox ];
        };
    }
    // lib.optionalAttrs isDarwin {
      homebrew.casks = [ "dropbox" ];
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

}
// lib.optionalAttrs isLinux {
  filelight = _: {
    home = _: { home.packages = [ pkgs.kdePackages.filelight ]; };
  };
  gparted = _: {
    home = _: { home.packages = [ pkgs.gparted ]; };
  };
  nautilus = _: {
    home = _: { home.packages = [ pkgs.nautilus ]; };
  };
  waypipe = _: {
    home = _: { home.packages = [ pkgs.waypipe ]; };
  };
}
