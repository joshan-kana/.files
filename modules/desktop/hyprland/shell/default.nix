{
  lib,
  pkgs,
  scopeConfig,
  ...
}:

let
  sessionTarget = "wayland-session@hyprland.desktop.target";

  resourceProbe = pkgs.writeShellApplication {
    name = "desktop-shell-resource-probe";
    text = builtins.readFile ../../../../scripts/desktop-shell/resource-probe.sh;
  };

  palettePython = pkgs.python3.withPackages (packages: [ packages.watchdog ]);

  paletteSearch = pkgs.writeShellApplication {
    name = "desktop-shell-palette-search";
    runtimeInputs = [
      palettePython
      pkgs.glib
    ];
    text = ''
      exec ${lib.getExe palettePython} ${../../../../scripts/desktop-shell/palette-search.py} "$@"
    '';
  };

in
{
  scopeOptions.quicklinks = lib.mkOption {
    type = lib.types.listOf (
      lib.types.submodule {
        options = {
          name = lib.mkOption { type = lib.types.str; };
          alias = lib.mkOption { type = lib.types.str; };
          url = lib.mkOption { type = lib.types.str; };
          keywords = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [ ];
          };
          browser = lib.mkOption {
            type = lib.types.str;
            default = "";
          };
        };
      }
    );
    description = "Declarative website search providers for the command palette.";
    default = [
      {
        name = "Search Nix Packages";
        alias = "np";
        url = "https://search.nixos.org/packages?query={query}";
        keywords = [
          "nixpkgs"
          "packages"
        ];
      }
      {
        name = "Search NixOS Options";
        alias = "no";
        url = "https://search.nixos.org/options?query={query}";
        keywords = [
          "nixos"
          "options"
        ];
      }
      {
        name = "Search NixOS Wiki";
        alias = "nw";
        url = "https://wiki.nixos.org/w/index.php?search={query}";
        keywords = [
          "nixos"
          "wiki"
        ];
      }
      {
        name = "Search ArchWiki";
        alias = "aw";
        url = "https://wiki.archlinux.org/index.php?search={query}";
        keywords = [
          "linux"
          "arch"
          "documentation"
        ];
      }
      {
        name = "Search Linux Man Pages";
        alias = "man";
        url = "https://www.mankier.com/search?q={query}";
        keywords = [
          "manual"
          "linux"
          "manpages"
        ];
      }
      {
        name = "Search GitHub";
        alias = "gh";
        url = "https://github.com/search?q={query}";
        keywords = [
          "repositories"
          "code"
        ];
      }
      {
        name = "Search GitHub Code";
        alias = "ghc";
        url = "https://github.com/search?type=code&q={query}";
        keywords = [
          "code"
          "repositories"
        ];
      }
      {
        name = "Search GitLab";
        alias = "gl";
        url = "https://gitlab.com/search?search={query}";
        keywords = [
          "repositories"
          "code"
        ];
      }
      {
        name = "Search MDN";
        alias = "mdn";
        url = "https://developer.mozilla.org/en-US/search?q={query}";
        keywords = [
          "web"
          "javascript"
          "css"
        ];
      }
      {
        name = "Search Stack Overflow";
        alias = "so";
        url = "https://stackoverflow.com/search?q={query}";
        keywords = [
          "questions"
          "programming"
        ];
      }
      {
        name = "Search crates.io";
        alias = "crates";
        url = "https://crates.io/search?q={query}";
        keywords = [
          "rust"
          "packages"
        ];
      }
      {
        name = "Search docs.rs";
        alias = "docsrs";
        url = "https://docs.rs/releases/search?query={query}";
        keywords = [
          "rust"
          "documentation"
        ];
      }
      {
        name = "Search PyPI";
        alias = "pypi";
        url = "https://pypi.org/search/?q={query}";
        keywords = [
          "python"
          "packages"
        ];
      }
      {
        name = "Search npm";
        alias = "npm";
        url = "https://www.npmjs.com/search?q={query}";
        keywords = [
          "javascript"
          "packages"
        ];
      }
      {
        name = "Search Homebrew";
        alias = "brew";
        url = "https://formulae.brew.sh/search/?q={query}";
        keywords = [
          "macos"
          "packages"
        ];
      }
      {
        name = "Search Docker Hub";
        alias = "docker";
        url = "https://hub.docker.com/search?q={query}";
        keywords = [
          "containers"
          "images"
        ];
      }
      {
        name = "Search DuckDuckGo";
        alias = "ddg";
        url = "https://duckduckgo.com/?q={query}";
        keywords = [
          "web"
          "search"
        ];
      }
      {
        name = "Search Google";
        alias = "gg";
        url = "https://www.google.com/search?q={query}";
        keywords = [
          "web"
          "search"
        ];
      }
      {
        name = "Search Bing";
        alias = "bing";
        url = "https://www.bing.com/search?q={query}";
        keywords = [
          "web"
          "search"
        ];
      }
      {
        name = "Search Kagi";
        alias = "kagi";
        url = "https://kagi.com/search?q={query}";
        keywords = [
          "web"
          "search"
        ];
      }
      {
        name = "Search Wikipedia";
        alias = "wiki";
        url = "https://en.wikipedia.org/w/index.php?search={query}";
        keywords = [ "encyclopedia" ];
      }
      {
        name = "Search Wiktionary";
        alias = "wikt";
        url = "https://en.wiktionary.org/w/index.php?search={query}";
        keywords = [ "dictionary" ];
      }
      {
        name = "Search Google Scholar";
        alias = "scholar";
        url = "https://scholar.google.com/scholar?q={query}";
        keywords = [
          "research"
          "academic"
        ];
      }
      {
        name = "Search arXiv";
        alias = "arxiv";
        url = "https://arxiv.org/search/?query={query}&searchtype=all";
        keywords = [
          "papers"
          "research"
        ];
      }
      {
        name = "Search YouTube";
        alias = "yt";
        url = "https://www.youtube.com/results?search_query={query}";
        keywords = [ "videos" ];
      }
      {
        name = "Search Reddit";
        alias = "rd";
        url = "https://www.reddit.com/search/?q={query}";
        keywords = [
          "community"
          "discussions"
        ];
      }
      {
        name = "Search IMDb";
        alias = "imdb";
        url = "https://www.imdb.com/find/?q={query}";
        keywords = [
          "movies"
          "television"
        ];
      }
      {
        name = "Search OpenStreetMap";
        alias = "osm";
        url = "https://www.openstreetmap.org/search?query={query}";
        keywords = [
          "maps"
          "places"
        ];
      }
      {
        name = "Translate with Google";
        alias = "trans";
        url = "https://translate.google.com/?sl=auto&tl=en&text={query}&op=translate";
        keywords = [
          "translation"
          "language"
        ];
      }
    ];
  };

  scopeOptions.fileSearchRoots = lib.mkOption {
    type = lib.types.listOf lib.types.str;
    default = [
      "Documents"
      "Downloads"
      "Desktop"
      "Projects"
      "repos"
      "src"
      "Uni"
    ];
    description = "Search roots relative to the home directory, or absolute paths, for the private palette index.";
  };

  scopeOptions.snippets = lib.mkOption {
    type = lib.types.listOf (
      lib.types.submodule {
        options = {
          name = lib.mkOption { type = lib.types.str; };
          text = lib.mkOption { type = lib.types.str; };
          keywords = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [ ];
          };
        };
      }
    );
    default = [ ];
    description = "Non-secret default snippets. User-owned snippets.json overrides these at runtime.";
  };

  scopeOptions.appearance = lib.mkOption {
    type = lib.types.submodule {
      options = {
        wallpaperSpectrumEnabled = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Enable the audio spectrum visualizer over the wallpaper.";
        };
        wallpaperResizeMode = lib.mkOption {
          type = lib.types.enum [
            "fit"
            "crop"
          ];
          default = "fit";
          description = "Scale selected wallpaper images to fit within the display or crop them to fill it.";
        };
        wallpaperTargetOutput = lib.mkOption {
          type = lib.types.str;
          default = "";
          description = "Display name for wallpaper selections. Empty uses the active display; \\\"all\\\" targets every display.";
        };
        musicReactiveEnabled = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Tint desktop shell surfaces in response to the currently playing audio.";
        };
        musicReactiveSensitivity = lib.mkOption {
          type = lib.types.numbers.between 0.4 3.0;
          default = 1.0;
          description = "Sensitivity multiplier for the single shared audio-reactive envelope.";
        };
        musicReactiveAttack = lib.mkOption {
          type = lib.types.numbers.between 0.5 2.5;
          default = 1.0;
          description = "Multiplier for how strongly beat transients respond.";
        };
        musicReactiveRelease = lib.mkOption {
          type = lib.types.numbers.between 0.4 2.5;
          default = 1.0;
          description = "Speed of the reactive beat-pulse release.";
        };
        musicReactiveSmoothing = lib.mkOption {
          type = lib.types.numbers.between 0.0 0.9;
          default = 0.0;
          description = "Smoothing coefficient for the sustained reactive envelope; zero preserves direct response.";
        };
        musicReactiveIntensity = lib.mkOption {
          type = lib.types.numbers.between 0.25 2.0;
          default = 1.0;
          description = "Visual intensity multiplier of the shell's existing music-reactive tint.";
        };
        musicReactiveEmphasis = lib.mkOption {
          type = lib.types.enum [
            "balanced"
            "bass"
            "mid"
            "treble"
          ];
          default = "balanced";
          description = "Frequency region emphasized by the reactive visual response.";
        };
        spectrumSensitivity = lib.mkOption {
          type = lib.types.numbers.between 0.4 3.0;
          default = 1.0;
          description = "Visual amplitude without changing the reactive tint.";
        };
        spectrumAttack = lib.mkOption {
          type = lib.types.numbers.between 0.25 2.5;
          default = 1.0;
          description = "Rise speed of visualizer bands.";
        };
        spectrumRelease = lib.mkOption {
          type = lib.types.numbers.between 0.25 2.5;
          default = 1.0;
          description = "Fall speed of visualizer bands.";
        };
        wallpaperSpectrumBars = lib.mkOption {
          type = lib.types.ints.between 24 96;
          default = 64;
          description = "Number of visible wallpaper spectrum bars, bounded by available analyser bands.";
        };
        wallpaperSpectrumOpacity = lib.mkOption {
          type = lib.types.numbers.between 0.2 1.0;
          default = 0.8;
          description = "Opacity of the existing wallpaper spectrum bars.";
        };

        barIslandHeight = lib.mkOption {
          type = lib.types.ints.between 44 60;
          default = 50;
          description = "Height of the desktop bar islands in logical pixels.";
        };
        frameThickness = lib.mkOption {
          type = lib.types.ints.between 18 36;
          default = 26;
          description = "Desktop frame thickness in logical pixels.";
        };
        barVisible = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Show the desktop island bar.";
        };
        frameVisible = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Show the desktop frame around the display.";
        };
        windowTransparencyEnabled = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Use the configured opacity for active and inactive application windows.";
        };
        shellGlassEnabled = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Use translucent shell surfaces with compositor backdrop blur.";
        };
        windowOpacity = lib.mkOption {
          type = lib.types.numbers.between 0.2 1.0;
          default = 0.82;
          description = "Opacity of application windows when transparency is enabled, from 0.2 to 1.0 inclusive.";
        };
        glassOpacity = lib.mkOption {
          type = lib.types.numbers.between 0.2 1.0;
          default = 0.70;
          description = "Opacity of translucent shell surfaces, from 0.2 to 1.0 inclusive.";
        };
        vhsEnabled = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Apply the VHS tape screen effect.";
        };
        vhsIntensity = lib.mkOption {
          type = lib.types.numbers.between 0.0 1.0;
          default = 0.45;
          description = "Strength of the VHS tape effect.";
        };
        vhsTracking = lib.mkOption {
          type = lib.types.numbers.between 0.0 1.0;
          default = 1.0;
          description = "Amount of rolling tracking distortion in the VHS effect.";
        };
        vhsChroma = lib.mkOption {
          type = lib.types.numbers.between 0.0 1.0;
          default = 1.0;
          description = "Strength of red-blue colour separation in the VHS effect.";
        };
        vhsNoise = lib.mkOption {
          type = lib.types.numbers.between 0.0 1.0;
          default = 1.0;
          description = "Strength of moving tape grain and luminance flicker.";
        };
        vhsScanlines = lib.mkOption {
          type = lib.types.numbers.between 0.0 1.0;
          default = 1.0;
          description = "Strength of VHS scanline darkening.";
        };
        vhsDropouts = lib.mkOption {
          type = lib.types.numbers.between 0.0 1.0;
          default = 0.0;
          description = "Strength of irregular horizontal black tape dropouts.";
        };
        vhsSpeed = lib.mkOption {
          type = lib.types.numbers.between 0.25 2.5;
          default = 1.0;
          description = "Playback speed multiplier for animated VHS distortion.";
        };
        mediaVisualizerMode = lib.mkOption {
          type = lib.types.enum [
            "bars"
            "curve"
          ];
          default = "bars";
          description = "Choose the media visualizer presentation: animated bars or a continuous curve.";
        };
        mediaLyricsVisible = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Show synchronized lyrics in the media view when the player supplies them.";
        };
        mediaPreferredPlayer = lib.mkOption {
          type = lib.types.str;
          default = "";
          description = "Preferred MPRIS desktop entry or stable application identity; empty selects automatically.";
        };
        mediaSeekSeconds = lib.mkOption {
          type = lib.types.enum [
            5
            10
            15
            30
            60
          ];
          default = 10;
          description = "Number of seconds to move forward or backward with the media seek actions.";
        };
      };
    };
    default = { };
    description = "Desktop appearance defaults. Explicit user preferences take precedence until restored to the declared values.";
  };

  scopeOptions.wallpaperRotation = lib.mkOption {
    type = lib.types.submodule {
      options = {
        mode = lib.mkOption {
          type = lib.types.enum [
            "off"
            "interval"
            "dayNight"
          ];
          default = "off";
        };
        target = lib.mkOption {
          type = lib.types.str;
          default = "all";
        };
        intervalMinutes = lib.mkOption {
          type = lib.types.enum [
            5
            15
            30
            60
            120
          ];
          default = 60;
        };
        favoritesOnly = lib.mkOption {
          type = lib.types.bool;
          default = false;
        };
        collection = lib.mkOption {
          type = lib.types.str;
          default = "";
        };
        dayStart = lib.mkOption {
          type = lib.types.ints.between 0 1439;
          default = 420;
        };
        nightStart = lib.mkOption {
          type = lib.types.ints.between 0 1439;
          default = 1140;
        };
        dayWallpaper = lib.mkOption {
          type = lib.types.str;
          default = "";
        };
        nightWallpaper = lib.mkOption {
          type = lib.types.str;
          default = "";
        };
      };
    };
    default = { };
    description = "Wallpaper rotation policy. Wallpaper paths and collections are relative to the user library; runtime overrides are independent.";
  };

  scopeOptions.captureLocations = lib.mkOption {
    type = lib.types.submodule {
      options = {
        screenshots = lib.mkOption {
          type = lib.types.str;
          default = "";
          description = "Absolute screenshot directory; empty uses the XDG Pictures directory.";
        };
        recordings = lib.mkOption {
          type = lib.types.str;
          default = "";
          description = "Absolute recording directory; empty uses the native recording directory.";
        };
      };
    };
    default = { };
    description = "Capture destination defaults; runtime selections override each directory independently.";
  };

  scopeOptions.captureFreezeEnabled = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = "Default frozen screenshot capture mode.";
  };

  scopeOptions.captureEncoding = lib.mkOption {
    type = lib.types.submodule {
      options = {
        imageFormat = lib.mkOption {
          type = lib.types.enum [
            "png"
            "jpg"
          ];
          default = "png";
        };
        jpegQuality = lib.mkOption {
          type = lib.types.enum [
            75
            85
            95
          ];
          default = 95;
        };
        cursor = lib.mkOption {
          type = lib.types.bool;
          default = false;
        };
        videoFormat = lib.mkOption {
          type = lib.types.enum [
            "mp4"
            "mkv"
          ];
          default = "mp4";
        };
        codec = lib.mkOption {
          type = lib.types.enum [
            "libx264"
            "libx265"
          ];
          default = "libx264";
        };
        frameRate = lib.mkOption {
          type = lib.types.enum [
            0
            30
            60
            120
          ];
          default = 0;
        };
        videoQuality = lib.mkOption {
          type = lib.types.enum [
            18
            23
            28
          ];
          default = 23;
        };
        countdown = lib.mkOption {
          type = lib.types.enum [
            0
            3
            5
            10
          ];
          default = 0;
        };
        audio = lib.mkOption {
          type = lib.types.enum [
            "none"
            "system"
            "microphone"
          ];
          default = "none";
        };
      };
    };
    default = { };
    description = "Capture encoding and recording defaults; user capture preferences override individual fields.";
  };

  scopeOptions.notificationApplications = lib.mkOption {
    type = lib.types.attrsOf (
      lib.types.submodule {
        options = {
          popups = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = "Allow application popups.";
          };
          history = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = "Retain application notification history.";
          };
          silent = lib.mkOption {
            type = lib.types.bool;
            default = false;
            description = "Suppress application popups.";
          };
          criticalOnly = lib.mkOption {
            type = lib.types.bool;
            default = false;
            description = "Show only critical popups.";
          };
          privatePreview = lib.mkOption {
            type = lib.types.bool;
            default = false;
            description = "Conceal notification content in popups.";
          };
        };
      }
    );
    default = { };
    description = "Application notification defaults keyed by desktop:<desktop-entry> or name:<application-name>, in lowercase.";
  };

  scopeOptions.notificationsSilent = lib.mkOption {
    type = lib.types.bool;
    default = false;
    description = "Default quiet notifications mode.";
  };

  scopeOptions.notificationQuietHours = lib.mkOption {
    type = lib.types.submodule {
      options = {
        enabled = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Enable scheduled quiet hours for ordinary notification popups.";
        };
        startMinute = lib.mkOption {
          type = lib.types.ints.between 0 1439;
          default = 1320;
          description = "Local minute of day when quiet hours start.";
        };
        endMinute = lib.mkOption {
          type = lib.types.ints.between 0 1439;
          default = 420;
          description = "Local minute of day when quiet hours end.";
        };
        days = lib.mkOption {
          type = lib.types.ints.between 0 127;
          default = 127;
          description = "Quiet-hour start-day mask, Sunday in bit zero.";
        };
      };
    };
    default = { };
    description = "Scheduled notification suppression defaults with per-field runtime overrides.";
  };

  scopeOptions.notificationsPresentation = lib.mkOption {
    type = lib.types.bool;
    default = false;
    description = "Default notification presentation mode (hide popups, retain Activity history).";
  };

  scopeOptions.notificationsHistoryEnabled = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = "Default notification history retention preference.";
  };

  scopeOptions.nightLight = lib.mkOption {
    type = lib.types.submodule {
      options = {
        mode = lib.mkOption {
          type = lib.types.enum [
            "off"
            "manual"
            "custom"
            "solar"
          ];
          default = "off";
          description = "Default Night Light operating mode.";
        };
        temperature = lib.mkOption {
          type = lib.types.ints.between 2500 6500;
          default = 4500;
          description = "Target colour temperature in Kelvin.";
        };
        startMinute = lib.mkOption {
          type = lib.types.ints.between 0 1439;
          default = 1140;
          description = "Local start minute for custom Night Light.";
        };
        endMinute = lib.mkOption {
          type = lib.types.ints.between 0 1439;
          default = 420;
          description = "Local end minute for custom Night Light.";
        };
        days = lib.mkOption {
          type = lib.types.ints.between 0 127;
          default = 127;
          description = "Custom schedule start-day mask, Sunday in bit zero.";
        };
        transitionMinutes = lib.mkOption {
          type = lib.types.ints.between 0 60;
          default = 15;
          description = "Duration of gradual colour-temperature transitions.";
        };
        latitude = lib.mkOption {
          type = lib.types.nullOr (lib.types.numbers.between (-90.0) 90.0);
          default = null;
          description = "Explicit solar latitude; null disables solar mode.";
        };
        longitude = lib.mkOption {
          type = lib.types.nullOr (lib.types.numbers.between (-180.0) 180.0);
          default = null;
          description = "Explicit solar longitude; null disables solar mode.";
        };
      };
    };
    default = { };
    description = "Night Light baseline, with individual runtime user overrides.";
  };

  scopeOptions.weatherUnits = lib.mkOption {
    type = lib.types.enum [
      "metric"
      "imperial"
    ];
    default = "metric";
    description = "Default units for the shared weather forecast.";
  };

  scopeOptions.weatherLocation = lib.mkOption {
    type = lib.types.str;
    default = "";
    description = "Optional weather city or latitude,longitude. Empty uses IP-based approximate lookup.";
  };

  scopeOptions.animationsEnabled = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = "Enable motion and animated transitions in the Hyprland desktop shell.";
  };

  scopeOptions.shellMotionSpeed = lib.mkOption {
    type = lib.types.numbers.between 0.75 1.5;
    default = 1.0;
    description = "Duration multiplier for animated shell transitions, independent of compositor animation rules.";
  };

  scopeOptions.resourceSampling = lib.mkOption {
    type = lib.types.submodule {
      options = {
        intervalSeconds = lib.mkOption {
          type = lib.types.enum [
            1
            2
            5
          ];
          default = 2;
        };
        historyLength = lib.mkOption {
          type = lib.types.enum [
            30
            60
            120
          ];
          default = 30;
        };
      };
    };
    default = { };
    description = "Visible resource dashboard sampling interval and bounded history length.";
  };

  scopeOptions.restoreWindowsOnExit = lib.mkOption {
    type = lib.types.bool;
    default = false;
    description = "Default to restoring windows after logout, reboot or poweroff from the desktop session panel.";
  };

  scopeOptions.textScale = lib.mkOption {
    type = lib.types.float;
    default = 1.0;
    description = "Scale text in the Hyprland desktop shell.";
  };

  scopeOptions.videoWallpaper = lib.mkOption {
    type = lib.types.nullOr lib.types.str;
    default = null;
    description = "Absolute path to a video wallpaper, played by mpvpaper over the Stylix background.";
  };

  assertions = [
    {
      assertion = scopeConfig.textScale >= 0.75 && scopeConfig.textScale <= 1.5;
      message = "desktop.hyprland.shell.textScale must be between 0.75 and 1.5";
    }
    {
      assertion = scopeConfig.videoWallpaper == null || lib.hasPrefix "/" scopeConfig.videoWallpaper;
      message = "desktop.hyprland.shell.videoWallpaper must be an absolute path";
    }
  ];

  home =
    {
      config,
      osConfig,
      pkgs,
      ...
    }:
    let
      productionShellPath = ./qml;
      developmentShellPath = "${osConfig.dotfiles.paths.repoPath}/modules/desktop/hyprland/shell/qml";
      json = pkgs.formats.json { };

      applyWallpaper = pkgs.writeShellApplication {
        name = "desktop-shell-wallpaper-apply";
        runtimeInputs = [
          wallpaperLibrary
          pkgs.awww
          pkgs.coreutils
          pkgs.jq
          pkgs.systemd
          pkgs.util-linux
        ];
        text =
          builtins.readFile ../../../../scripts/desktop-shell/wallpaper-common.sh
          + builtins.readFile ../../../../scripts/desktop-shell/wallpaper-apply.sh;
      };

      wallpaperLibrary = pkgs.writeShellApplication {
        name = "desktop-shell-wallpaper-library";
        runtimeInputs = [
          pkgs.awww
          pkgs.coreutils
          pkgs.findutils
          pkgs.ffmpeg
          pkgs.jq
          pkgs.systemd
          pkgs.util-linux
        ];
        text =
          builtins.readFile ../../../../scripts/desktop-shell/wallpaper-common.sh
          + builtins.readFile ../../../../scripts/desktop-shell/wallpaper-library.sh;
      };

      wallpaperPolicy = pkgs.writeShellApplication {
        name = "desktop-shell-wallpaper-policy";
        runtimeInputs = [
          pkgs.python3
          pkgs.systemd
        ];
        text = ''
          export DESKTOP_WALLPAPER_LIBRARY=${lib.escapeShellArg (lib.getExe wallpaperLibrary)}
          export DESKTOP_WALLPAPER_POLICY_DEFAULTS=${lib.escapeShellArg (builtins.toJSON scopeConfig.wallpaperRotation)}
          exec python3 ${../../../../scripts/desktop-shell/wallpaper-policy.py} "$@"
        '';
      };

      wallpaperVideoFromState = pkgs.writeShellApplication {
        name = "desktop-shell-wallpaper-video-from-state";
        runtimeInputs = [
          pkgs.jq
          pkgs.awww
          pkgs.mpvpaper
          pkgs.coreutils
        ];
        text = builtins.readFile ../../../../scripts/desktop-shell/wallpaper-video-from-state.sh;
      };

      # The subscribed iCal URL is a runtime-only secret. Google Calendar
      # publishes a standard VCALENDAR feed; khal already owns local event UI.
      agendaIcalSource = ../../../../scripts/desktop-shell/ical-sync.py;

      agendaIcalSync = pkgs.writeShellApplication {
        name = "desktop-shell-ical-sync";
        runtimeInputs = [
          pkgs.python3
          pkgs.vdirsyncer
        ];
        text = ''
          exec python3 ${agendaIcalSource}
        '';
      };

      agendaSetup = pkgs.writeShellApplication {
        name = "desktop-shell-agenda-setup";
        runtimeInputs = [ pkgs.coreutils ];
        text = builtins.readFile ../../../../scripts/desktop-shell/agenda-setup.sh;
      };

      agendaQuerySource = ../../../../scripts/desktop-shell/agenda-query.py;

      agendaQuery = pkgs.writeShellApplication {
        name = "desktop-shell-agenda-query";
        runtimeInputs = [
          pkgs.python3
          pkgs.khal
        ];
        text = ''
          exec python3 ${agendaQuerySource} "$@"
        '';
      };

      clipboardPreview = pkgs.writeShellApplication {
        name = "desktop-shell-clipboard-preview";
        runtimeInputs = [
          clipboardOperations
          pkgs.cliphist
          pkgs.coreutils
          pkgs.imagemagick
        ];
        text = builtins.readFile ../../../../scripts/desktop-shell/clipboard-preview.sh;
      };

      clipboardCopy = pkgs.writeShellApplication {
        name = "desktop-shell-clipboard-copy";
        runtimeInputs = [
          pkgs.cliphist
          pkgs.wl-clipboard
        ];
        text = builtins.readFile ../../../../scripts/desktop-shell/clipboard-copy.sh;
      };

      clipboardOperationsSource = ../../../../scripts/desktop-shell/clipboard-operations.py;

      clipboardOperations = pkgs.writeShellApplication {
        name = "desktop-shell-clipboard-operations";
        runtimeInputs = [
          pkgs.cliphist
          pkgs.python3
          pkgs.wl-clipboard
        ];
        text = ''
          exec python3 ${clipboardOperationsSource} "$@"
        '';
      };

      spectrumAnalyzer = pkgs.desktop-shell-spectrum;

      keybindings = (import ../keybindings.nix).bindings {
        terminal = osConfig.dotfiles.defaults.terminal;
        browser = osConfig.dotfiles.defaults.browser;
      };
      mainModifierLabel = config.wayland.windowManager.hyprland.settings.mainMod._var;
      mehModifierLabel = config.wayland.windowManager.hyprland.settings.mehMod._var;
      launcherSlotBindings = lib.filter (
        binding:
        binding.submap == "launcher"
        && binding.action.type == "global"
        && lib.hasPrefix "desktop-shell:launcher-slot-" binding.action.value
      ) keybindings;
      launcherSlotsHint =
        if launcherSlotBindings == [ ] then
          ""
        else
          "${mainModifierLabel} + ${(builtins.head launcherSlotBindings).key}–${(lib.last launcherSlotBindings).key}";

      navigationKey =
        id:
        let
          binding = lib.findFirst (entry: entry.id == id && entry.submap == null) null keybindings;
        in
        if binding == null then throw "Missing canonical navigation shortcut: ${id}" else binding.key;

      renderShortcut =
        binding:
        let
          modLabel =
            modifier:
            if modifier == "main" then
              mainModifierLabel
            else if modifier == "meh" then
              mehModifierLabel
            else
              lib.toUpper modifier;
          key = if binding.label != null then binding.label else binding.key;
        in
        lib.concatStringsSep " + " ((map modLabel binding.mods) ++ [ key ]);

      cheatsheetBindings = map (binding: {
        key = renderShortcut binding;
        inherit (binding) description section;
      }) (lib.filter (binding: binding.cheatsheet) keybindings);

      shortcuts = lib.listToAttrs (
        map (binding: {
          name = binding.id;
          value = renderShortcut binding;
        }) (lib.filter (binding: binding.id != null) keybindings)
      );

      vhsControl = pkgs.writeShellApplication {
        name = "desktop-shell-vhs";
        runtimeInputs = [
          pkgs.coreutils
          pkgs.gnused
          osConfig.programs.hyprland.package
        ];
        text = ''
          export VHS_SHADER_SOURCE=${lib.escapeShellArg "${./shaders/vhs.frag}"}
          ${builtins.readFile ../../../../scripts/desktop-shell/vhs.sh}
        '';
      };

      runtimeConfig = json.generate "desktop-shell-runtime.json" {
        wallpaperVideoDefault = scopeConfig.videoWallpaper;
        defaults = {
          terminal = osConfig.dotfiles.defaults.terminal;
          editor = osConfig.dotfiles.defaults.editor;
        };

        accessibility.textScale = scopeConfig.textScale;
        motion.animationsEnabled = scopeConfig.animationsEnabled;
        motion.durationMultiplier = scopeConfig.shellMotionSpeed;
        inherit (scopeConfig) resourceSampling;
        session.restoreWindowsOnExit = scopeConfig.restoreWindowsOnExit;
        palette = {
          inherit (scopeConfig) quicklinks;
          inherit (scopeConfig) snippets;
          fileRoots = scopeConfig.fileSearchRoots;
        };
        # Compositor blur is declared by Hyprland itself. The shell only
        # receives evaluated defaults for its transient/persistent user overrides.
        appearance = scopeConfig.appearance // {
          blurEnabled = config.wayland.windowManager.hyprland.settings.config.decoration.blur.enabled;
          blurSize = config.wayland.windowManager.hyprland.settings.config.decoration.blur.size;
        };
        capture.freezeEnabled = scopeConfig.captureFreezeEnabled;
        capture.encoding = scopeConfig.captureEncoding;
        notifications = {
          silent = scopeConfig.notificationsSilent;
          presentation = scopeConfig.notificationsPresentation;
          historyEnabled = scopeConfig.notificationsHistoryEnabled;
          quietHours = scopeConfig.notificationQuietHours;
          applications = scopeConfig.notificationApplications;
        };
        weather.location = scopeConfig.weatherLocation;
        weather.units = scopeConfig.weatherUnits;
        keybindings = cheatsheetBindings;
        shortcutHints = {
          launcherSlots = launcherSlotsHint;
          hubPrevious = navigationKey "workspace.previous";
          hubNext = navigationKey "workspace.next";
          statusInspect = navigationKey "status.inspect";
          microphoneMute = navigationKey "audio.microphoneMute";
          passthruExit =
            let
              binding = lib.findFirst (
                entry: entry.id == "keyboard.passthruExit" && entry.submap == "passthru"
              ) null keybindings;
            in
            if binding == null then
              throw "Missing canonical passthrough exit shortcut"
            else
              renderShortcut binding;
        };
        inherit shortcuts;
        shellBindings = import ./keybindings.nix;

        tools = {
          pwMetadata = lib.getExe' pkgs.pipewire "pw-metadata";
          bluetoothctl = lib.getExe' pkgs.bluez "bluetoothctl";
          weatherCurl = lib.getExe pkgs.curl;
          agendaQuery = lib.getExe agendaQuery;
          agendaSetup = lib.getExe agendaSetup;
          brightnessctl = lib.getExe pkgs.brightnessctl;
          cliphist = lib.getExe pkgs.cliphist;
          emojiTest = "${pkgs.unicode-emoji}/share/unicode/emoji/emoji-test.txt";
          resourceProbe = lib.getExe resourceProbe;
          clipboardCopy = lib.getExe clipboardCopy;
          copyText = lib.getExe' pkgs.wl-clipboard "wl-copy";
          clipboardPreview = lib.getExe clipboardPreview;
          clipboardOperations = lib.getExe clipboardOperations;
          lockSession = lib.getExe lockCommand;
          networkConnectionEditor = lib.getExe' pkgs.networkmanagerapplet "nm-connection-editor";
          nmcli = lib.getExe' pkgs.networkmanager "nmcli";
          hyprctl = lib.getExe' osConfig.programs.hyprland.package "hyprctl";
          easyeffects = lib.getExe pkgs.easyeffects;
          easyeffectsCli = lib.getExe (
            pkgs.writeShellApplication {
              name = "desktop-shell-easyeffects-cli";
              runtimeInputs = [ pkgs.easyeffects ];
              text = ''
                export LC_ALL=C
                exec easyeffects "$@"
              '';
            }
          );
          vhsControl = lib.getExe vhsControl;
          sessionCommand = lib.getExe sessionCommand;
          urlOpen = lib.getExe' pkgs.xdg-utils "xdg-open";
          paletteSearch = lib.getExe paletteSearch;
          clipboardPaste = lib.getExe' pkgs.wl-clipboard "wl-paste";
          wallpaperLibrary = lib.getExe wallpaperLibrary;
          wallpaperPolicy = lib.getExe wallpaperPolicy;
          recordingToggle = lib.getExe recordingToggle;
          recordingLibrary = lib.getExe recordingLibrary;
          captureLocations = lib.getExe captureLocations;
          frozenCapture = lib.getExe frozenCapture;
          colourPicker = lib.getExe colourPicker;
          nightLightControl = lib.getExe nightLightControl;
          displaySettings = lib.getExe pkgs.nwg-displays;
          displayControl = lib.getExe displayControl;
          notifySend = lib.getExe' pkgs.libnotify "notify-send";
        };
      };

      launcher = pkgs.writeShellApplication {
        name = "desktop-shell";
        runtimeInputs = [ pkgs.quickshell ];
        text = ''
          export DESKTOP_SHELL_RUNTIME="''${XDG_CONFIG_HOME:-$HOME/.config}/desktop-shell/runtime.json"
          export QML_IMPORT_PATH="${pkgs.desktop-shell-visuals}/lib/qt-6/qml''${QML_IMPORT_PATH:+:$QML_IMPORT_PATH}"
          export QS_ICON_THEME=${lib.escapeShellArg config.gtk.iconTheme.name}
          exec qs --path "${productionShellPath}" "$@"
        '';
      };

      developmentLauncher = pkgs.writeShellApplication {
        name = "desktop-shell-dev";
        runtimeInputs = [ pkgs.quickshell ];
        text = ''
          export DESKTOP_SHELL_RUNTIME="''${XDG_CONFIG_HOME:-$HOME/.config}/desktop-shell/runtime.json"
          export QML_IMPORT_PATH="${pkgs.desktop-shell-visuals}/lib/qt-6/qml''${QML_IMPORT_PATH:+:$QML_IMPORT_PATH}"
          export QS_ICON_THEME=${lib.escapeShellArg config.gtk.iconTheme.name}
          exec qs --path ${lib.escapeShellArg developmentShellPath} "$@"
        '';
      };

      lockServiceLauncher = pkgs.writeShellApplication {
        name = "desktop-shell-lock-shell";
        runtimeInputs = [ pkgs.quickshell ];
        text = ''
          export DESKTOP_SHELL_RUNTIME="''${XDG_CONFIG_HOME:-$HOME/.config}/desktop-shell/runtime.json"
          export QML_IMPORT_PATH="${pkgs.desktop-shell-visuals}/lib/qt-6/qml''${QML_IMPORT_PATH:+:$QML_IMPORT_PATH}"
          export QS_ICON_THEME=${lib.escapeShellArg config.gtk.iconTheme.name}
          exec qs --no-duplicate --path "${productionShellPath}/lock.qml"
        '';
      };

      lockCommand = pkgs.writeShellApplication {
        name = "desktop-shell-lock";
        runtimeInputs = [
          pkgs.coreutils
          pkgs.systemd
        ];
        text = builtins.readFile ../../../../scripts/desktop-shell/lock.sh;
      };

      displayControl = pkgs.writeShellApplication {
        name = "desktop-shell-display-control";
        runtimeInputs = [
          pkgs.python3
          pkgs.systemd
          osConfig.programs.hyprland.package
        ];
        text = ''
          exec python3 ${../../../../scripts/desktop-shell/display-settings.py} "$@"
        '';
      };

      nightLightControl = pkgs.writeShellApplication {
        name = "desktop-shell-night-light";
        runtimeInputs = [
          pkgs.systemd
          pkgs.hyprsunset
          osConfig.programs.hyprland.package
          (pkgs.python3.withPackages (ps: [ ps.astral ]))
        ];
        text = ''
          export DESKTOP_NIGHT_LIGHT_DEFAULTS=${lib.escapeShellArg (builtins.toJSON scopeConfig.nightLight)}
          exec python3 ${../../../../scripts/desktop-shell/night-light.py} "$@"
        '';
      };

      colourPicker = pkgs.writeShellApplication {
        name = "desktop-shell-pick-colour";
        runtimeInputs = [
          pkgs.bash
          pkgs.hyprpicker
          pkgs.wl-clipboard
          pkgs.libnotify
          pkgs.systemd
        ];
        text = builtins.readFile ../../../../scripts/desktop-shell/pick-colour.sh;
      };

      captureLocations = pkgs.writeShellApplication {
        name = "desktop-shell-capture-locations";
        runtimeInputs = [
          pkgs.python3
          pkgs.systemd
          pkgs.kdePackages.kdialog
        ];
        text = ''
          ${lib.optionalString (scopeConfig.captureLocations.screenshots != "")
            "export DESKTOP_SHELL_SCREENSHOT_DIR=${lib.escapeShellArg scopeConfig.captureLocations.screenshots}"
          }
          ${lib.optionalString (scopeConfig.captureLocations.recordings != "")
            "export DESKTOP_SHELL_RECORDING_DIR=${lib.escapeShellArg scopeConfig.captureLocations.recordings}"
          }
          exec python3 ${../../../../scripts/desktop-shell/capture-locations.py} "$@"
        '';
      };

      recordRegion = pkgs.writeShellApplication {
        name = "desktop-shell-record-region";
        runtimeInputs = [
          captureLocations
          pkgs.coreutils
          pkgs.slurp
          pkgs.wf-recorder
          pkgs.pulseaudio
        ];
        text = builtins.readFile ../../../../scripts/desktop-shell/record-region.sh;
      };

      imageMarkup = pkgs.writeShellApplication {
        name = "desktop-shell-markup";
        runtimeInputs = [
          pkgs.coreutils
          pkgs.file
          pkgs.kdePackages.kdialog
          pkgs.satty
          pkgs.wl-clipboard
        ];
        text = builtins.readFile ../../../../scripts/desktop-shell/markup.sh;
      };

      frozenCapture = pkgs.writeShellApplication {
        name = "desktop-shell-frozen-capture";
        runtimeInputs = [
          captureLocations
          captureNotify
          pkgs.grim
          pkgs.imagemagick
          pkgs.coreutils
          pkgs.wl-clipboard
          pkgs.systemd
          pkgs.satty
        ];
        text = builtins.readFile ../../../../scripts/desktop-shell/frozen-capture.sh;
      };

      recordingToggle = pkgs.writeShellApplication {
        name = "desktop-shell-recording-toggle";
        runtimeInputs = [
          pkgs.systemd
          pkgs.coreutils
        ];
        text = builtins.readFile ../../../../scripts/desktop-shell/recording-toggle.sh;
      };

      notificationOpen = pkgs.writeShellApplication {
        name = "desktop-shell-open-capture";
        runtimeInputs = [
          captureLocations
          imageMarkup
          pkgs.quickshell
          pkgs.xdg-utils
          pkgs.losslesscut
        ];
        text = ''
          export DESKTOP_SHELL_SHELL_PATH=${lib.escapeShellArg "${productionShellPath}"}
          ${builtins.readFile ../../../../scripts/desktop-shell/open-capture.sh}
        '';
      };

      captureNotify = pkgs.writeShellApplication {
        name = "desktop-shell-capture-notify";
        runtimeInputs = [
          notificationOpen
          recordingLibrary
          pkgs.coreutils
          pkgs.libnotify
        ];
        text = builtins.readFile ../../../../scripts/desktop-shell/capture-notify.sh;
      };

      recordingLibrary = pkgs.writeShellApplication {
        name = "desktop-shell-recordings";
        runtimeInputs = [
          captureLocations
          pkgs.tesseract
          imageMarkup
          pkgs.coreutils
          pkgs.findutils
          pkgs.glib
          pkgs.ffmpeg
          pkgs.jq
          pkgs.gnused
          pkgs.xdg-utils
          pkgs.losslesscut
          pkgs.wl-clipboard
        ];
        text = builtins.readFile ../../../../scripts/desktop-shell/recordings.sh;
      };

      recordingFinalize = pkgs.writeShellApplication {
        name = "desktop-shell-recording-finalize";
        runtimeInputs = [
          captureNotify
          pkgs.coreutils
          pkgs.ffmpeg
          pkgs.libnotify
          pkgs.systemd
        ];
        text = builtins.readFile ../../../../scripts/desktop-shell/recording-finalize.sh;
      };

      sessionCommand = pkgs.writeShellApplication {
        name = "desktop-shell-session";
        runtimeInputs = [
          pkgs.coreutils
          pkgs.hypr-persist
          pkgs.libnotify
          pkgs.systemd
          pkgs.uwsm
        ];
        text = builtins.readFile ../../../../scripts/desktop-shell/session.sh;
      };
    in
    {
      # Hyprland draws and hit-tests lower order values above higher ones.
      # Keep interactive shell surfaces above ordinary overlay clients regardless
      # of map order, while preserving the priority of global modal dialogs.
      wayland.windowManager.hyprland.settings.layer_rule = [
        {
          match.namespace = "^desktop-shell-expansion$";
          order = -10;
        }
        {
          match.namespace = "^desktop-shell-notification-popup$";
          order = -15;
        }
        {
          match.namespace = "^desktop-shell-modal$";
          order = -20;
        }
        {
          match.namespace = "^desktop-shell-capture$";
          order = -30;
        }
        {
          match.namespace = "^desktop-shell-authentication$";
          order = -40;
        }
      ];

      services.awww.enable = true;

      home.packages = [
        launcher
        paletteSearch
        developmentLauncher
        lockCommand
        sessionCommand
        clipboardCopy
        clipboardOperations
        wallpaperLibrary
        recordingToggle
        imageMarkup
        (pkgs.makeDesktopItem {
          name = "desktop-shell-markup";
          desktopName = "Annotate Image";
          genericName = "Screenshot and image markup";
          exec = "${lib.getExe imageMarkup} %f";
          icon = "accessories-text-editor";
          categories = [ "Graphics" ];
          mimeTypes = [
            "image/png"
            "image/jpeg"
            "image/webp"
            "image/bmp"
            "image/gif"
          ];
        })
        colourPicker
        nightLightControl
        agendaIcalSync
        pkgs.quickshell
        pkgs.mpvpaper
        spectrumAnalyzer
      ];

      xdg.configFile."desktop-shell/runtime.json".source = runtimeConfig;

      systemd.user.paths.desktop-shell-wallpaper-image = {
        Unit.Description = "Reload wallpaper when the selected theme changes";
        Unit.PartOf = [ sessionTarget ];
        Path.PathChanged = "%h/.config/desktop-shell/theme.json";
        Install.WantedBy = [ sessionTarget ];
      };

      systemd.user.timers.desktop-shell-ical-sync = {
        Unit.Description = "Refresh the local read-only iCalendar subscription";
        Timer = {
          OnCalendar = "*:0/30";
          RandomizedDelaySec = "90s";
          Persistent = true;
          Unit = "desktop-shell-ical-sync.service";
        };
        Install.WantedBy = [ "timers.target" ];
      };

      systemd.user.timers.desktop-shell-wallpaper-rotation = {
        Unit = {
          Description = "Re-evaluate the active wallpaper rotation policy";
          PartOf = [ sessionTarget ];
        };
        Timer = {
          OnCalendar = "*-*-* *:*:00";
          AccuracySec = "1s";
          Unit = "desktop-shell-wallpaper-rotation.service";
        };
      };

      systemd.user.timers.desktop-shell-display-preview = {
        Unit.Description = "Revert an unconfirmed display layout";
        Timer = {
          OnActiveSec = "20s";
          AccuracySec = "100ms";
          Unit = "desktop-shell-display-preview.service";
        };
      };

      systemd.user.timers.desktop-shell-night-light-apply = {
        Unit = {
          Description = "Re-evaluate Night Light schedules and overrides";
          PartOf = [ sessionTarget ];
        };
        Timer = {
          OnCalendar = "*-*-* *:*:00";
          AccuracySec = "1s";
          Unit = "desktop-shell-night-light-apply.service";
        };
      };

      systemd.user.services = {
        desktop-shell-wallpaper-rotation = {
          Unit = {
            Description = "Apply the active wallpaper rotation policy";
            After = [ "desktop-shell-wallpaper-image.service" ];
            PartOf = [ sessionTarget ];
          };
          Service = {
            Type = "oneshot";
            ExecStart = "${lib.getExe wallpaperPolicy} apply";
          };
          Install.WantedBy = [ sessionTarget ];
        };

        desktop-shell-display-preview = {
          Unit.Description = "Restore the previous display layout";
          Service = {
            Type = "oneshot";
            ExecStart = "${lib.getExe displayControl} rollback";
          };
        };

        desktop-shell-palette-index = {
          Unit = {
            Description = "Watch local files and bookmarks for command palette indexing";
            PartOf = [ sessionTarget ];
          };
          Service = {
            Type = "simple";
            ExecStart = "${lib.getExe paletteSearch} watch";
            Restart = "on-failure";
            RestartSec = "5s";
          };
          Install.WantedBy = [ sessionTarget ];
        };

        desktop-shell-ical-sync = {
          Unit = {
            Description = "Refresh subscribed iCalendar events for khal";
          };
          Service = {
            Type = "oneshot";
            ExecStart = lib.getExe agendaIcalSync;
            # Three feeds can independently exhaust bounded download and sync timeouts.
            TimeoutStartSec = 300;
          };
        };

        desktop-shell-wallpaper-image = {
          Unit = {
            Description = "Apply the Stylix wallpaper with awww transitions";
            Wants = [ "awww.service" ];
            After = [
              "awww.service"
              sessionTarget
            ];
            PartOf = [ sessionTarget ];
          };

          Service = {
            Type = "oneshot";
            ExecStart = lib.getExe applyWallpaper;
            Restart = "on-failure";
            RestartSec = 2;
          };

          Install.WantedBy = [ sessionTarget ];
        };

        "desktop-shell-wallpaper-video@" = {
          Unit = {
            Description = "Selected video wallpaper on %i";
            PartOf = [ sessionTarget ];
            Wants = [ "awww.service" ];
            After = [
              "awww.service"
              sessionTarget
            ];
          };
          Service = {
            ExecStart = "${lib.getExe wallpaperVideoFromState} %i";
            Restart = "on-failure";
            RestartSec = 2;
          };
        };

        desktop-shell-night-light = {
          Unit = {
            Description = "Hyprland colour temperature";
            After = [ sessionTarget ];
            PartOf = [ sessionTarget ];
            # Rapid manual temperature changes must never permanently lock
            # Night Light out with start-limit-hit.
            StartLimitIntervalSec = 0;
          };
          Service = {
            ExecStart = "${lib.getExe nightLightControl} run";
            # Hyprsunset aborts when the Wayland/CTM connection disappears
            # during a compositor reset. Recover while the session remains up;
            # an explicit stop (Night Light off) must still stay stopped.
            Restart = "on-failure";
            RestartSec = 2;
          };
        };

        desktop-shell-night-light-apply = {
          Unit = {
            Description = "Apply Night Light policy and scheduled colour temperature";
            After = [ sessionTarget ];
          };
          Service = {
            Type = "oneshot";
            ExecStart = "${lib.getExe nightLightControl} apply";
          };
          Install.WantedBy = [ sessionTarget ];
        };

        desktop-shell-spectrum = {
          Unit = {
            Description = "Hyprland desktop audio spectrum analyser";
            PartOf = [ sessionTarget ];
            After = [
              sessionTarget
              "pipewire.service"
            ];
          };

          Service = {
            ExecStart = lib.getExe spectrumAnalyzer;
            Restart = "on-failure";
            RestartSec = 1;
          };

          Install.WantedBy = [ sessionTarget ];
        };

        desktop-shell-recording = {
          Unit = {
            Description = "Record a selected Wayland screen region";
            PartOf = [ sessionTarget ];
            After = [ sessionTarget ];
          };
          Service = {
            ExecStart = lib.getExe recordRegion;
            UMask = "0077";
            ExecStopPost = lib.getExe recordingFinalize;
            KillSignal = "SIGINT";
            TimeoutStopSec = 15;
            Restart = "no";
          };
        };

        desktop-shell-lock = {
          Unit = {
            Description = "Hyprland desktop session lock";
            PartOf = [ sessionTarget ];
            After = [ sessionTarget ];
            X-SwitchMethod = "keep-old";
          };

          Service = {
            ExecStart = lib.getExe lockServiceLauncher;
            UMask = "0077";
            Restart = "no";
          };
        };

        desktop-shell = {
          Unit = {
            Description = "Hyprland desktop shell";
            # Home Manager replaces both configuration symlinks on theme
            # switches. FileView may keep watching the former store target,
            # so restart when either evaluated source changes.
            X-Restart-Triggers = [
              runtimeConfig
              config.xdg.configFile."desktop-shell/theme.json".source
            ];
            PartOf = [ sessionTarget ];
            Wants = [ "desktop-shell-spectrum.service" ];
            After = [
              sessionTarget
              "desktop-shell-spectrum.service"
            ];
          };

          Service = {
            ExecStartPre = "${lib.getExe' pkgs.coreutils "touch"} %t/desktop-shell-recording.state";
            ExecStart = "${lib.getExe launcher} --no-duplicate";
            UMask = "0077";
            Restart = "on-failure";
            RestartSec = 1;
          };

          Install.WantedBy = [ sessionTarget ];
        };
      };
    };
}
