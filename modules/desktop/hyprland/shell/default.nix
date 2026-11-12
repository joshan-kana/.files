{
  lib,
  pkgs,
  scopeConfig,
  ...
}:

let
  sessionTarget = "wayland-session@hyprland.desktop.target";

  resourceProbe = pkgs.writeShellApplication {
    name = "linux-desktop-resource-probe";
    text = builtins.readFile ./scripts/resource-probe.sh;
  };

  palettePython = pkgs.python3.withPackages (packages: [ packages.watchdog ]);

  paletteSearch = pkgs.writeShellApplication {
    name = "linux-desktop-palette-search";
    runtimeInputs = [
      palettePython
      pkgs.glib
    ];
    text = ''
      exec ${lib.getExe palettePython} ${./scripts/palette-search.py} "$@"
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

  scopeOptions.captureFreezeEnabled = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = "Default frozen screenshot capture mode.";
  };

  scopeOptions.notificationsSilent = lib.mkOption {
    type = lib.types.bool;
    default = false;
    description = "Default quiet notifications mode.";
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
        name = "linux-desktop-wallpaper-apply";
        runtimeInputs = [
          wallpaperLibrary
          pkgs.awww
          pkgs.coreutils
          pkgs.jq
          pkgs.systemd
          pkgs.util-linux
        ];
        text = ''
          source ${./scripts/wallpaper-common.sh}
        ''
        + builtins.readFile ./scripts/wallpaper-apply.sh;
      };

      wallpaperLibrary = pkgs.writeShellApplication {
        name = "linux-desktop-wallpaper-library";
        runtimeInputs = [
          pkgs.awww
          pkgs.coreutils
          pkgs.findutils
          pkgs.ffmpeg
          pkgs.jq
          pkgs.systemd
          pkgs.util-linux
        ];
        text = ''
          source ${./scripts/wallpaper-common.sh}
        ''
        + builtins.readFile ./scripts/wallpaper-library.sh;
      };

      wallpaperVideoFromState = pkgs.writeShellApplication {
        name = "linux-desktop-wallpaper-video-from-state";
        runtimeInputs = [
          pkgs.jq
          pkgs.awww
          pkgs.mpvpaper
          pkgs.coreutils
        ];
        text = builtins.readFile ./scripts/wallpaper-video-from-state.sh;
      };

      # The subscribed iCal URL is a runtime-only secret. Google Calendar
      # publishes a standard VCALENDAR feed; khal already owns local event UI.
      agendaIcalSource = ./scripts/ical-sync.py;

      agendaIcalSync = pkgs.writeShellApplication {
        name = "linux-desktop-ical-sync";
        runtimeInputs = [ (pkgs.python3.withPackages (python: [ python.icalendar ])) ];
        text = ''
          exec python3 ${agendaIcalSource}
        '';
      };

      agendaSetup = pkgs.writeShellApplication {
        name = "linux-desktop-agenda-setup";
        runtimeInputs = [ pkgs.coreutils ];
        text = builtins.readFile ./scripts/agenda-setup.sh;
      };

      agendaQuerySource = ./scripts/agenda-query.py;

      agendaQuery = pkgs.writeShellApplication {
        name = "linux-desktop-agenda-query";
        runtimeInputs = [
          pkgs.python3
          pkgs.khal
        ];
        text = ''
          exec python3 ${agendaQuerySource} "$@"
        '';
      };

      clipboardPreview = pkgs.writeShellApplication {
        name = "linux-desktop-clipboard-preview";
        runtimeInputs = [
          pkgs.cliphist
          pkgs.coreutils
          pkgs.imagemagick
        ];
        text = builtins.readFile ./scripts/clipboard-preview.sh;
      };

      clipboardCopy = pkgs.writeShellApplication {
        name = "linux-desktop-clipboard-copy";
        runtimeInputs = [
          pkgs.cliphist
          pkgs.wl-clipboard
        ];
        text = builtins.readFile ./scripts/clipboard-copy.sh;
      };

      spectrumAnalyzer = pkgs.linux-desktop-spectrum;

      keybindings = import ../keybindings.nix {
        terminal = osConfig.dotfiles.defaults.terminal;
        browser = osConfig.dotfiles.defaults.browser;
      };
      mainModifierLabel = config.wayland.windowManager.hyprland.settings.mainMod._var;
      mehModifierLabel = config.wayland.windowManager.hyprland.settings.mehMod._var;
      launcherSlotBindings = lib.filter (
        binding:
        binding.submap == "launcher"
        && binding.action.type == "global"
        && lib.hasPrefix "linux-desktop:launcher-slot-" binding.action.value
      ) keybindings;
      launcherSlotsHint =
        if launcherSlotBindings == [ ] then
          ""
        else
          "${mainModifierLabel} + ${(builtins.head launcherSlotBindings).keys}–${(lib.last launcherSlotBindings).keys}";

      renderShortcut =
        binding:
        let
          key = if binding.label != null then binding.label else binding.keys;
        in
        "${lib.optionalString binding.mehMod "${mehModifierLabel} + "}${lib.optionalString binding.mainMod "${mainModifierLabel} + "}${key}";

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

      runtimeConfig = json.generate "linux-desktop-runtime.json" {
        wallpaperVideoDefault = scopeConfig.videoWallpaper;
        defaults = {
          terminal = osConfig.dotfiles.defaults.terminal;
          editor = osConfig.dotfiles.defaults.editor;
        };

        accessibility.textScale = scopeConfig.textScale;
        motion.animationsEnabled = scopeConfig.animationsEnabled;
        session.restoreWindowsOnExit = scopeConfig.restoreWindowsOnExit;
        palette = {
          inherit (scopeConfig) quicklinks;
          inherit (scopeConfig) snippets;
          fileRoots = scopeConfig.fileSearchRoots;
        };
        inherit (scopeConfig) appearance;
        capture.freezeEnabled = scopeConfig.captureFreezeEnabled;
        notifications = {
          silent = scopeConfig.notificationsSilent;
          presentation = scopeConfig.notificationsPresentation;
          historyEnabled = scopeConfig.notificationsHistoryEnabled;
        };
        weather.location = scopeConfig.weatherLocation;
        keybindings = cheatsheetBindings;
        shortcutHints.launcherSlots = launcherSlotsHint;
        inherit shortcuts;

        tools = {
          bluetoothctl = lib.getExe' pkgs.bluez "bluetoothctl";
          weatherCurl = lib.getExe pkgs.curl;
          agendaQuery = lib.getExe agendaQuery;
          agendaSetup = lib.getExe agendaSetup;
          brightnessctl = lib.getExe pkgs.brightnessctl;
          cliphist = lib.getExe pkgs.cliphist;
          emojiTest = "${pkgs.unicode-emoji}/share/unicode/emoji/emoji-test.txt";
          resourceProbe = lib.getExe resourceProbe;
          clipboardCopy = lib.getExe clipboardCopy;
          clipboardPreview = lib.getExe clipboardPreview;
          lockSession = lib.getExe lockCommand;
          networkConnectionEditor = lib.getExe' pkgs.networkmanagerapplet "nm-connection-editor";
          nmcli = lib.getExe' pkgs.networkmanager "nmcli";
          hyprctl = lib.getExe' osConfig.programs.hyprland.package "hyprctl";
          powerprofilesctl = lib.getExe' pkgs.power-profiles-daemon "powerprofilesctl";
          powerprofilesMonitor = lib.getExe' pkgs.dbus "dbus-monitor";
          sessionCommand = lib.getExe sessionCommand;
          urlOpen = lib.getExe' pkgs.xdg-utils "xdg-open";
          paletteSearch = lib.getExe paletteSearch;
          clipboardPaste = lib.getExe' pkgs.wl-clipboard "wl-paste";
          wallpaperLibrary = lib.getExe wallpaperLibrary;
          recordingToggle = lib.getExe recordingToggle;
          recordingLibrary = lib.getExe recordingLibrary;
          frozenCapture = lib.getExe frozenCapture;
          colourPicker = lib.getExe colourPicker;
          nightLightControl = lib.getExe nightLightControl;
        };
      };

      launcher = pkgs.writeShellApplication {
        name = "linux-desktop";
        runtimeInputs = [ pkgs.quickshell ];
        text = ''
          export LINUX_DESKTOP_RUNTIME="''${XDG_CONFIG_HOME:-$HOME/.config}/linux-desktop/runtime.json"
          export QML_IMPORT_PATH="${pkgs.linux-desktop-visuals}/lib/qt-6/qml''${QML_IMPORT_PATH:+:$QML_IMPORT_PATH}"
          exec qs --path "${productionShellPath}" "$@"
        '';
      };

      developmentLauncher = pkgs.writeShellApplication {
        name = "linux-desktop-dev";
        runtimeInputs = [ pkgs.quickshell ];
        text = ''
          export LINUX_DESKTOP_RUNTIME="''${XDG_CONFIG_HOME:-$HOME/.config}/linux-desktop/runtime.json"
          export QML_IMPORT_PATH="${pkgs.linux-desktop-visuals}/lib/qt-6/qml''${QML_IMPORT_PATH:+:$QML_IMPORT_PATH}"
          exec qs --path ${lib.escapeShellArg developmentShellPath} "$@"
        '';
      };

      lockServiceLauncher = pkgs.writeShellApplication {
        name = "linux-desktop-lock-shell";
        runtimeInputs = [ pkgs.quickshell ];
        text = ''
          export LINUX_DESKTOP_RUNTIME="''${XDG_CONFIG_HOME:-$HOME/.config}/linux-desktop/runtime.json"
          export QML_IMPORT_PATH="${pkgs.linux-desktop-visuals}/lib/qt-6/qml''${QML_IMPORT_PATH:+:$QML_IMPORT_PATH}"
          exec qs --no-duplicate --path "${productionShellPath}/lock.qml"
        '';
      };

      lockCommand = pkgs.writeShellApplication {
        name = "linux-desktop-lock";
        runtimeInputs = [
          pkgs.coreutils
          pkgs.systemd
        ];
        text = builtins.readFile ./scripts/lock.sh;
      };

      nightLightControl = pkgs.writeShellApplication {
        name = "linux-desktop-night-light";
        runtimeInputs = [
          pkgs.coreutils
          pkgs.systemd
          pkgs.hyprsunset
        ];
        text = builtins.readFile ./scripts/night-light.sh;
      };

      colourPicker = pkgs.writeShellApplication {
        name = "linux-desktop-pick-colour";
        runtimeInputs = [
          pkgs.bash
          pkgs.hyprpicker
          pkgs.wl-clipboard
          pkgs.libnotify
          pkgs.systemd
        ];
        text = builtins.readFile ./scripts/pick-colour.sh;
      };

      recordRegion = pkgs.writeShellApplication {
        name = "linux-desktop-record-region";
        runtimeInputs = [
          pkgs.coreutils
          pkgs.slurp
          pkgs.wf-recorder
          pkgs.pulseaudio
        ];
        text = builtins.readFile ./scripts/record-region.sh;
      };

      imageMarkup = pkgs.writeShellApplication {
        name = "linux-desktop-markup";
        runtimeInputs = [
          pkgs.coreutils
          pkgs.file
          pkgs.kdePackages.kdialog
          pkgs.satty
          pkgs.wl-clipboard
        ];
        text = builtins.readFile ./scripts/markup.sh;
      };

      frozenCapture = pkgs.writeShellApplication {
        name = "linux-desktop-frozen-capture";
        runtimeInputs = [
          captureNotify
          pkgs.grim
          pkgs.imagemagick
          pkgs.coreutils
          pkgs.wl-clipboard
          pkgs.systemd
          pkgs.satty
        ];
        text = builtins.readFile ./scripts/frozen-capture.sh;
      };

      recordingToggle = pkgs.writeShellApplication {
        name = "linux-desktop-recording-toggle";
        runtimeInputs = [
          pkgs.systemd
          pkgs.coreutils
        ];
        text = builtins.readFile ./scripts/recording-toggle.sh;
      };

      notificationOpen = pkgs.writeShellApplication {
        name = "linux-desktop-open-capture";
        runtimeInputs = [
          imageMarkup
          pkgs.xdg-utils
          pkgs.losslesscut
        ];
        text = builtins.readFile ./scripts/open-capture.sh;
      };

      captureNotify = pkgs.writeShellApplication {
        name = "linux-desktop-capture-notify";
        runtimeInputs = [
          notificationOpen
          pkgs.coreutils
          pkgs.libnotify
        ];
        text = builtins.readFile ./scripts/capture-notify.sh;
      };

      recordingLibrary = pkgs.writeShellApplication {
        name = "linux-desktop-recordings";
        runtimeInputs = [
          imageMarkup
          pkgs.coreutils
          pkgs.findutils
          pkgs.glib
          pkgs.ffmpeg
          pkgs.gnused
          pkgs.xdg-utils
          pkgs.losslesscut
          pkgs.wl-clipboard
        ];
        text = builtins.readFile ./scripts/recordings.sh;
      };

      recordingFinalize = pkgs.writeShellApplication {
        name = "linux-desktop-recording-finalize";
        runtimeInputs = [
          captureNotify
          pkgs.coreutils
          pkgs.ffmpeg
          pkgs.libnotify
          pkgs.systemd
        ];
        text = builtins.readFile ./scripts/recording-finalize.sh;
      };

      sessionCommand = pkgs.writeShellApplication {
        name = "linux-desktop-session";
        runtimeInputs = [
          pkgs.coreutils
          pkgs.hypr-persist
          pkgs.libnotify
          pkgs.systemd
          pkgs.uwsm
        ];
        text = builtins.readFile ./scripts/session.sh;
      };
    in
    {
      services.awww.enable = true;

      home.packages = [
        launcher
        paletteSearch
        developmentLauncher
        lockCommand
        sessionCommand
        clipboardCopy
        wallpaperLibrary
        recordingToggle
        imageMarkup
        (pkgs.makeDesktopItem {
          name = "linux-desktop-markup";
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

      xdg.configFile."linux-desktop/runtime.json".source = runtimeConfig;

      systemd.user.paths.linux-desktop-wallpaper-image = {
        Unit.Description = "Reload wallpaper when the selected theme changes";
        Unit.PartOf = [ sessionTarget ];
        Path.PathChanged = "%h/.config/linux-desktop/theme.json";
        Install.WantedBy = [ sessionTarget ];
      };

      systemd.user.timers.linux-desktop-ical-sync = {
        Unit.Description = "Refresh the local read-only iCalendar subscription";
        Timer = {
          OnCalendar = "*:0/30";
          RandomizedDelaySec = "90s";
          Persistent = true;
          Unit = "linux-desktop-ical-sync.service";
        };
        Install.WantedBy = [ "timers.target" ];
      };

      systemd.user.services = {
        linux-desktop-palette-index = {
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

        linux-desktop-ical-sync = {
          Unit = {
            Description = "Refresh subscribed iCalendar events for khal";
          };
          Service = {
            Type = "oneshot";
            ExecStart = lib.getExe agendaIcalSync;
            TimeoutStartSec = 45;
          };
        };

        linux-desktop-wallpaper-image = {
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

        "linux-desktop-wallpaper-video@" = {
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

        linux-desktop-night-light = {
          Unit = {
            Description = "Manual Hyprland colour temperature";
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

        linux-desktop-night-light-apply = {
          Unit = {
            Description = "Restore manual Night Light state at session start";
            After = [ sessionTarget ];
          };
          Service = {
            Type = "oneshot";
            ExecStart = "${lib.getExe nightLightControl} apply";
          };
          Install.WantedBy = [ sessionTarget ];
        };

        linux-desktop-spectrum = {
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

        linux-desktop-recording = {
          Unit = {
            Description = "Record a selected Wayland screen region";
            PartOf = [ sessionTarget ];
            After = [ sessionTarget ];
          };
          Service = {
            ExecStart = lib.getExe recordRegion;
            ExecStopPost = lib.getExe recordingFinalize;
            KillSignal = "SIGINT";
            TimeoutStopSec = 15;
            Restart = "no";
          };
        };

        linux-desktop-lock = {
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

        linux-desktop = {
          Unit = {
            Description = "Hyprland desktop shell";
            # Home Manager replaces both configuration symlinks on theme
            # switches. FileView may keep watching the former store target,
            # so restart when either evaluated source changes.
            X-Restart-Triggers = [
              runtimeConfig
              config.xdg.configFile."linux-desktop/theme.json".source
            ];
            PartOf = [ sessionTarget ];
            Wants = [ "linux-desktop-spectrum.service" ];
            After = [
              sessionTarget
              "linux-desktop-spectrum.service"
            ];
          };

          Service = {
            ExecStartPre = "${lib.getExe' pkgs.coreutils "touch"} %t/linux-desktop-recording.state";
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
