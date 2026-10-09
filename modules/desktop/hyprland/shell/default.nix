{
  config,
  configurationFlakeSubdirectory ? null,
  configurationName,
  configurationOutputName,
  inputs,
  lib,
  pkgs,
  scopeConfig,
  ...
}:

let
  themeRegistry = import ../../../theme/registry.nix { inherit lib pkgs; };
  primaryUser = config.dotfiles.users.primary.name;
  configuredTheme =
    if configurationFlakeSubdirectory == "themes" then
      lib.removePrefix "${configurationName}-" configurationOutputName
    else
      themeRegistry.default;
  themeFlake = "path:${inputs.self.outPath}?dir=themes";
  themeNames = builtins.attrNames themeRegistry.variants;

  themeManifest = pkgs.writeText "dotfiles-theme-registry.json" (
    builtins.toJSON {
      inherit (themeRegistry) default;
      themes = lib.mapAttrsToList (
        name: value:
        {
          inherit name;
          inherit (value) label;
        }
        // lib.optionalAttrs (value ? colors) {
          preview =
            let
              inherit (value) colors;
            in
            {
              background = "#${colors.base00}";
              surface = "#${colors.base01}";
              outline = "#${colors.base03}";
              text = "#${colors.base05}";
              swatches = [
                "#${colors.base08}"
                "#${colors.base0A}"
                "#${colors.base0B}"
                "#${colors.base0D}"
                "#${colors.base0E}"
              ];
            };
        }
      ) themeRegistry.variants;
    }
  );

  themeSet = pkgs.writeShellApplication {
    name = "theme-set";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.nix
    ];
    text = ''
      defaultTheme=${lib.escapeShellArg themeRegistry.default}
      configuredTheme=${lib.escapeShellArg configuredTheme}
      expectedUser=${lib.escapeShellArg primaryUser}
      themeFlake=${lib.escapeShellArg themeFlake}
      manifest=${lib.escapeShellArg (toString themeManifest)}
      stateDir="''${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles"
      stateFile="$stateDir/theme"

      resolve_theme() {
        case "$1" in
          ${lib.concatStringsSep "|" themeNames})
            return 0
            ;;
          *)
            return 1
            ;;
        esac
      }

      write_state() {
        selected="$1"
        umask 077
        install -d -m 0700 "$stateDir"
        tmp="$(mktemp "$stateDir/theme.XXXXXX")"
        printf '%s\n' "$selected" > "$tmp"
        mv "$tmp" "$stateFile"
      }

      current_theme() {
        if [ -s "$stateFile" ]; then
          selected="$(cat "$stateFile")"
          if resolve_theme "$selected"; then
            printf '%s\n' "$selected"
            return
          fi
        fi

        printf '%s\n' "$configuredTheme"
      }

      validate_theme_request() {
        selected="$1"

        if [ "''${USER:-}" != "$expectedUser" ]; then
          printf 'theme-set is configured for user %s, not %s\n' "$expectedUser" "''${USER:-unknown}" >&2
          exit 1
        fi

        if ! resolve_theme "$selected"; then
          printf 'Unknown theme: %s\n' "$selected" >&2
          exit 2
        fi
      }

      build_theme() {
        selected="$1"
        validate_theme_request "$selected"

        nix build \
          --no-link \
          --print-out-paths \
          "$themeFlake#nixosConfigurations.${configurationName}-$selected.config.home-manager.users.${primaryUser}.home.activationPackage"
      }

      activate_built_theme() {
        selected="$1"
        activation="$2"
        validate_theme_request "$selected"

        case "$activation" in
          /nix/store/*)
            ;;
          *)
            printf 'Invalid theme activation path: %s\n' "$activation" >&2
            exit 3
            ;;
        esac

        if [ ! -x "$activation/activate" ]; then
          printf 'Theme activation is not executable: %s/activate\n' "$activation" >&2
          exit 3
        fi

        XDG_DATA_DIRS="$activation/home-path/share''${XDG_DATA_DIRS:+:$XDG_DATA_DIRS}" \
          "$activation/activate" --driver-version 1

        write_state "$selected"
        printf '%s\n' "$selected"
      }

      apply_theme() {
        selected="$1"
        activation="$(build_theme "$selected")"
        activate_built_theme "$selected" "$activation"
      }

      case "''${1:-}" in
        list)
          if [ "''${2:-}" = "--json" ]; then
            cat "$manifest"
          else
            while IFS= read -r name; do
              printf '%s\n' "$name"
            done <<'EOF'
      ${lib.concatStringsSep "\n" themeNames}
      EOF
          fi
          ;;
        current)
          current_theme
          ;;
        build)
          if [ -z "''${2:-}" ]; then
            printf 'Usage: theme-set build <theme>\n' >&2
            exit 2
          fi
          build_theme "$2"
          ;;
        activate-built)
          if [ -z "''${2:-}" ] || [ -z "''${3:-}" ]; then
            printf 'Usage: theme-set activate-built <theme> <activation-path>\n' >&2
            exit 2
          fi
          activate_built_theme "$2" "$3"
          ;;
        restore)
          # A full themed NixOS generation is authoritative. Record it rather
          # than overriding it with an older runtime-only selection.
          if [ "$configuredTheme" != "$defaultTheme" ]; then
            write_state "$configuredTheme"
            exit 0
          fi

          selected="$(current_theme)"
          if [ "$selected" != "$configuredTheme" ]; then
            apply_theme "$selected" >/dev/null
          fi
          ;;
        "")
          printf 'Usage: theme-set [list [--json]|current|restore|build <theme>|activate-built <theme> <activation-path>|<theme>]\n' >&2
          exit 2
          ;;
        *)
          apply_theme "$1"
          ;;
      esac
    '';
  };

  shellVisual = {
    panelOpacity = 0.99;
    focusOpacity = 0.96;
    scrimOpacity = 0.50;
    squircleExponent = 4.5;
  };
in
{
  environment.systemPackages = [ themeSet ];

  systemd.services."home-manager-${primaryUser}".serviceConfig.ExecStartPost =
    "${lib.getExe themeSet} restore";

  scopeOptions.animationsEnabled = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = "Enable motion and animated transitions in the Hyprland desktop shell.";
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
      colors = config.lib.stylix.colors.withHashtag;

      applyWallpaper = pkgs.writeShellApplication {
        name = "linux-desktop-wallpaper-apply";
        runtimeInputs = [
          pkgs.awww
          pkgs.coreutils
          pkgs.jq
          pkgs.systemd
          pkgs.util-linux
        ];
        text = ''
          exec 9>"''${XDG_RUNTIME_DIR:?}/linux-desktop-wallpaper.lock"
          flock -n 9 || exit 0

          runtime="''${XDG_CONFIG_HOME:-$HOME/.config}/linux-desktop/runtime.json"
          wallpaper="$(jq -er '.wallpaper | select(type == "string" and length > 0)' "$runtime")"

          if [ ! -f "$wallpaper" ]; then
            printf 'Wallpaper does not exist: %s\n' "$wallpaper" >&2
            exit 1
          fi

          # The service can start before the Wayland daemon has opened its socket.
          for _ in {1..25}; do
            if awww query >/dev/null 2>&1; then
              quiet="$XDG_RUNTIME_DIR/linux-desktop-wallpaper-motion-disabled"
              transition=fade
              [ ! -f "$quiet" ] || transition=none
              awww img --transition-type "$transition" --transition-duration 0.8 --transition-fps 165 "$wallpaper"

              # The Stylix wallpaper remains the default. Reapply user-selected
              # per-output overrides after a theme reload or session restart.
              state_dir="''${XDG_STATE_HOME:-$HOME/.local/state}/linux-desktop/wallpapers"
              for entry in "$state_dir"/*.wall; do
                [ -f "$entry" ] || continue
                { IFS= read -r resize && IFS= read -r image; } < "$entry" || continue
                [ -f "$image" ] || continue
                output="$(basename "$entry" .wall)"
                args=()
                [ "$output" = all ] || args=(--outputs "$output")
                case "''${image,,}" in
                  *.mp4|*.webm|*.mkv|*.mov)
                    if [ -f "$quiet" ]; then
                      systemctl --user stop --no-block "linux-desktop-wallpaper-video@$output.service" || true
                      still="$(${lib.getExe wallpaperLibrary} thumbnail "$image")" || continue
                      awww img "''${args[@]}" --resize "$resize" --transition-type none "$still"
                    else
                      awww clear "''${args[@]}" 000000
                      systemctl --user start --no-block "linux-desktop-wallpaper-video@$output.service"
                    fi
                    ;;
                  *)
                    still="$image"
                    if [ -f "$quiet" ] && [[ "''${image,,}" = *.gif ]]; then
                      still="$(${lib.getExe wallpaperLibrary} thumbnail "$image")" || continue
                    fi
                    awww img "''${args[@]}" --resize "$resize" --transition-type "$transition" --transition-duration 0.8 --transition-fps 165 "$still"
                    ;;
                esac
              done
              exit 0
            fi
            sleep 0.2
          done

          printf 'awww daemon is not ready\n' >&2
          exit 1
        '';
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
          library="$HOME/Pictures/Wallpapers"
          state_dir="''${XDG_STATE_HOME:-$HOME/.local/state}/linux-desktop/wallpapers"
          runtime="''${XDG_CONFIG_HOME:-$HOME/.config}/linux-desktop/runtime.json"
          action="''${1:-}"
          output="''${2:-all}"
          if [ "$action" = thumbnail ]; then
            image="$output"
            [ -f "$image" ] && [[ "$image" = /* ]] || exit 2
            case "''${image,,}" in
              *.gif|*.mp4|*.webm|*.mkv|*.mov)
                cache="''${XDG_CACHE_HOME:-$HOME/.cache}/linux-desktop/wallpaper-thumbnails"
                mkdir -p "$cache"
                key="$(printf '%s:%s' "$image" "$(stat -c '%Y:%s' "$image")" | sha256sum | cut -d' ' -f1)"
                thumb="$cache/$key.png"
                if [ ! -s "$thumb" ]; then
                  tmp="$(mktemp "$cache/.thumb.XXXXXXXX.png")"
                  trap 'rm -f "$tmp"' EXIT
                  ffmpeg -nostdin -v error -i "$image" -frames:v 1 -vf 'scale=380:250:force_original_aspect_ratio=decrease' -update 1 -y "$tmp"
                  mv -f "$tmp" "$thumb"
                fi
                printf '%s\n' "$thumb"
                ;;
              *) printf '%s\n' "$image" ;;
            esac
            exit 0
          fi

          case "$output" in
            *[!a-zA-Z0-9_.-]*|"") printf 'Invalid output name: %s\n' "$output" >&2; exit 2 ;;
          esac
          state_file="$state_dir/$output.wall"

          if [ "$action" = motion ]; then
            quiet="$XDG_RUNTIME_DIR/linux-desktop-wallpaper-motion-disabled"
            case "$output" in
              off) touch "$quiet" ;;
              on) rm -f "$quiet" ;;
              *) exit 2 ;;
            esac
            systemctl --user start --no-block linux-desktop-wallpaper-image.service
            exit 0
          fi

          case "$action" in
            list)
              if [ -d "$library" ]; then
                find "$library" -type f \(                   -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' -o                   -iname '*.webp' -o -iname '*.bmp' -o -iname '*.gif' -o -iname '*.mp4' -o -iname '*.webm' -o -iname '*.mkv' -o -iname '*.mov' \) -print                   | LC_ALL=C sort | jq -Rsc '[split("\n")[] | select(length > 0)]'
              else
                printf '[]\n'
              fi
              ;;
            current)
              if [ -f "$state_file" ]; then
                { IFS= read -r resize && IFS= read -r image; } < "$state_file" || exit 1
                printf '%s\n' "$image"
              else
                jq -er '.wallpaper' "$runtime"
              fi
              ;;
            set)
              resize="''${3:-crop}"
              image="''${4:-}"
              case "$resize" in crop|fit) ;; *) printf 'Invalid resize mode\n' >&2; exit 2 ;; esac
              case "''${image,,}" in
                *.png|*.jpg|*.jpeg|*.webp|*.bmp|*.gif) kind=image ;;
                *.mp4|*.webm|*.mkv|*.mov) kind=video ;;
                *) printf 'Unsupported wallpaper image: %s\n' "$image" >&2; exit 2 ;;
              esac
              if [ ! -f "$image" ] || [ "''${image:0:1}" != / ]; then
                printf 'Wallpaper must be an existing absolute file path\n' >&2
                exit 2
              fi
              exec 9>"''${XDG_RUNTIME_DIR:?}/linux-desktop-wallpaper.lock"
              flock -x 9
              unit="linux-desktop-wallpaper-video@$output.service"
              args=()
              [ "$output" = all ] || args=(--outputs "$output")
              if [ "$kind" = video ]; then
                ffprobe -v error -select_streams v:0 -show_entries stream=codec_type -of csv=p=0 "$image" | grep -qx video || exit 2
                if [ -f "$XDG_RUNTIME_DIR/linux-desktop-wallpaper-motion-disabled" ]; then
                  still="$("$0" thumbnail "$image")"
                  awww img "''${args[@]}" --resize "$resize" --transition-type none "$still"
                else
                  awww clear "''${args[@]}" 000000
                fi
              else
                systemctl --user stop "$unit" || true
                still="$image"
                if [ -f "$XDG_RUNTIME_DIR/linux-desktop-wallpaper-motion-disabled" ] && [[ "''${image,,}" = *.gif ]]; then
                  still="$("$0" thumbnail "$image")"
                fi
                transition=fade
                [ ! -f "$XDG_RUNTIME_DIR/linux-desktop-wallpaper-motion-disabled" ] || transition=none
                awww img "''${args[@]}" --resize "$resize" --transition-type "$transition" --transition-duration 0.8 --transition-fps 165 "$still"
              fi
              mkdir -p "$state_dir"
              temp="$(mktemp "$state_dir/.wallpaper.XXXXXXXX")"
              trap 'rm -f "$temp"' EXIT
              printf '%s\n%s\n' "$resize" "$image" > "$temp"
              mv -f "$temp" "$state_file"
              if [ "$kind" = video ]; then
                systemctl --user restart "$unit"
              fi
              ;;
            reset)
              systemctl --user stop "linux-desktop-wallpaper-video@$output.service" || true
              rm -f "$state_file"
              systemctl --user start --no-block linux-desktop-wallpaper-image.service
              ;;
            *)
              printf 'Usage: linux-desktop-wallpaper-library {list|current [output]|set output crop\|fit /abs/file|reset [output]|thumbnail /abs/file|motion on\|off}\n' >&2
              exit 2
              ;;
          esac
        '';
      };

      wallpaperVideoFromState = pkgs.writeShellApplication {
        name = "linux-desktop-wallpaper-video-from-state";
        runtimeInputs = [
          pkgs.mpvpaper
          pkgs.coreutils
        ];
        text = ''
          output="''${1:?Output required}"
          file="''${XDG_STATE_HOME:-$HOME/.local/state}/linux-desktop/wallpapers/$output.wall"
          [ -r "$file" ] || exit 0
          { IFS= read -r resize && IFS= read -r video; } < "$file" || exit 1
          [ -f "$video" ] || exit 1
          case "''${video,,}" in *.mp4|*.webm|*.mkv|*.mov) ;; *) exit 0 ;; esac
          [ "$output" != all ] || output='*'
          [ ! -f "$XDG_RUNTIME_DIR/linux-desktop-wallpaper-motion-disabled" ] || exit 0
          options='no-audio loop-file=inf hwdec=auto'
          [ "$resize" != crop ] || options="$options panscan=1"
          exec mpvpaper -p -a full -l bottom -o "$options" "$output" "$video"
        '';
      };

      videoWallpaper = pkgs.writeShellApplication {
        name = "linux-desktop-wallpaper-video";
        runtimeInputs = [
          pkgs.awww
          pkgs.coreutils
          pkgs.mpvpaper
          pkgs.systemd
          pkgs.util-linux
        ];
        text = ''
          mpvOptions='no-audio loop-file=inf hwdec=auto'
          case "''${1:-}" in
            --fit)
              shift
              ;;
            --fill)
              mpvOptions="$mpvOptions panscan=1"
              shift
              ;;
          esac

          if [ "$#" -ne 1 ] || [ ! -f "$1" ]; then
            printf 'Usage: linux-desktop-wallpaper-video [--fit|--fill] <video-file>\n' >&2
            exit 2
          fi

          exec 9>"''${XDG_RUNTIME_DIR:?}/linux-desktop-wallpaper.lock"
          if ! flock -n 9; then
            printf 'Another wallpaper operation is already in progress\n' >&2
            exit 1
          fi

          # mpvpaper preserves video aspect ratio, leaving transparent borders.
          # Cover those borders with a solid color, not the previous wallpaper.
          for _ in {1..25}; do
            if awww clear 000000 >/dev/null 2>&1; then
              break
            fi
            sleep 0.2
          done
          if ! awww query >/dev/null 2>&1; then
            printf 'awww daemon is not ready\n' >&2
            exit 1
          fi

          restore() {
            flock -u 9
            systemctl --user start linux-desktop-wallpaper-image.service || true
          }
          trap restore EXIT
          trap 'exit 130' INT
          trap 'exit 143' TERM

          mpvpaper -l bottom -o "$mpvOptions" '*' "$1"
        '';
      };

      agendaQuery = pkgs.writeShellApplication {
        name = "linux-desktop-agenda-query";
        runtimeInputs = [
          pkgs.coreutils
          pkgs.jq
          pkgs.khal
        ];
        text = ''
          if [ "$#" -ne 1 ] || [[ ! "$1" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
            printf 'Usage: linux-desktop-agenda-query YYYY-MM-DD\n' >&2
            exit 2
          fi

          # Khal reads local iCalendar vdirs, including recurrence and time zones.
          # Calendar synchronisation and credentials belong to the calendar client.
          if [ ! -f "''${XDG_CONFIG_HOME:-$HOME/.config}/khal/config" ]; then
            printf '{"configured":false,"events":[]}\n'
            exit 0
          fi

          # khal's end date is inclusive; seven calendar days means +6 days.
          endDate="$(date -d "$1 + 6 days" +%Y-%m-%d)"
          khal list \
            --json title --json start-date --json start-time \
            --json end-time --json location \
            "$1" "$endDate" \
            | jq -sc '{configured:true,events: (add | map({
                date: .["start-date"],
                time: .["start-time"],
                endTime: .["end-time"],
                title: .title,
                location: .location
              }) | sort_by(.date, .time, .title))}'
        '';
      };

      clipboardCopy = pkgs.writeShellApplication {
        name = "linux-desktop-clipboard-copy";
        runtimeInputs = [
          pkgs.cliphist
          pkgs.wl-clipboard
        ];
        text = ''
          id="''${1:-}"

          if ! [[ "$id" =~ ^[0-9]+$ ]]; then
            exit 2
          fi

          cliphist decode "$id" | wl-copy
        '';
      };

      spectrumAnalyzer = pkgs.stdenv.mkDerivation {
        pname = "linux-desktop-spectrum";
        version = "0.1.0";
        src = ./spectrum;

        nativeBuildInputs = [ pkgs.pkg-config ];
        buildInputs = [ pkgs.pipewire ];

        buildPhase = ''
          runHook preBuild

          $CXX             -std=c++20             -O3             -DNDEBUG             -Wall             -Wextra             main.cpp             -o linux-desktop-spectrum             $(pkg-config --cflags --libs libpipewire-0.3)             -pthread

          runHook postBuild
        '';

        installPhase = ''
          runHook preInstall
          install -Dm755 linux-desktop-spectrum "$out/bin/linux-desktop-spectrum"
          runHook postInstall
        '';

        meta.mainProgram = "linux-desktop-spectrum";
      };

      keybindings = import ../keybindings.nix {
        terminal = osConfig.dotfiles.defaults.terminal;
      };
      mainModifierLabel = config.wayland.windowManager.hyprland.settings.mainMod._var;
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
        "${lib.optionalString binding.mainMod "${mainModifierLabel} + "}${key}";

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
        defaults = {
          terminal = osConfig.dotfiles.defaults.terminal;
          editor = osConfig.dotfiles.defaults.editor;
        };

        theme = {
          background = colors.base00;
          surface = colors.base01;
          surfaceRaised = colors.base02;
          outline = colors.base03;
          textMuted = colors.base04;
          text = colors.base05;
          textStrong = colors.base06;
          critical = colors.base08;
          warning = colors.base0A;
          positive = colors.base0B;
          accent = colors.base0D;
        };

        fonts.mono = config.stylix.fonts.monospace.name;

        accessibility.textScale = scopeConfig.textScale;
        motion.animationsEnabled = scopeConfig.animationsEnabled;
        visual = shellVisual;
        keybindings = cheatsheetBindings;
        shortcutHints.launcherSlots = launcherSlotsHint;
        inherit shortcuts;

        tools = {
          bluetoothctl = lib.getExe' pkgs.bluez "bluetoothctl";
          weatherCurl = lib.getExe pkgs.curl;
          agendaQuery = lib.getExe agendaQuery;
          brightnessctl = lib.getExe pkgs.brightnessctl;
          cliphist = lib.getExe pkgs.cliphist;
          clipboardCopy = lib.getExe clipboardCopy;
          lockSession = lib.getExe lockCommand;
          networkConnectionEditor = lib.getExe' pkgs.networkmanagerapplet "nm-connection-editor";
          powerprofilesctl = lib.getExe' pkgs.power-profiles-daemon "powerprofilesctl";
          sessionCommand = lib.getExe sessionCommand;
          themeSet = lib.getExe themeSet;
          wallpaperLibrary = lib.getExe wallpaperLibrary;
          recordingToggle = lib.getExe recordingToggle;
        };

        wallpaper = toString osConfig.stylix.image;
      };

      launcher = pkgs.writeShellApplication {
        name = "linux-desktop";
        runtimeInputs = [ pkgs.quickshell ];
        text = ''
          export LINUX_DESKTOP_RUNTIME="''${XDG_CONFIG_HOME:-$HOME/.config}/linux-desktop/runtime.json"
          export LINUX_DESKTOP_THEME_STATE="''${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles/theme"
          exec qs --path "${productionShellPath}" "$@"
        '';
      };

      developmentLauncher = pkgs.writeShellApplication {
        name = "linux-desktop-dev";
        runtimeInputs = [ pkgs.quickshell ];
        text = ''
          export LINUX_DESKTOP_RUNTIME="''${XDG_CONFIG_HOME:-$HOME/.config}/linux-desktop/runtime.json"
          export LINUX_DESKTOP_THEME_STATE="''${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles/theme"
          exec qs --path ${lib.escapeShellArg developmentShellPath} "$@"
        '';
      };

      lockServiceLauncher = pkgs.writeShellApplication {
        name = "linux-desktop-lock-shell";
        runtimeInputs = [ pkgs.quickshell ];
        text = ''
          export LINUX_DESKTOP_RUNTIME="''${XDG_CONFIG_HOME:-$HOME/.config}/linux-desktop/runtime.json"
          export LINUX_DESKTOP_THEME_STATE="''${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles/theme"
          exec qs --no-duplicate --path "${productionShellPath}/lock.qml"
        '';
      };

      lockCommand = pkgs.writeShellApplication {
        name = "linux-desktop-lock";
        runtimeInputs = [ pkgs.systemd ];
        text = ''
          exec systemctl --user start linux-desktop-lock.service
        '';
      };

      recordRegion = pkgs.writeShellApplication {
        name = "linux-desktop-record-region";
        runtimeInputs = [
          pkgs.coreutils
          pkgs.slurp
          pkgs.wf-recorder
        ];
        text = ''
          geometry="$(slurp -d)" || exit 0
          [ -n "$geometry" ] || exit 0
          directory="''${LINUX_DESKTOP_RECORDING_DIR:-$HOME/Videos/Screencasts}"
          mkdir -p "$directory"
          output="$directory/Recording-$(date +%Y%m%d-%H%M%S)-$$.mp4"
          exec wf-recorder --geometry "$geometry" --file "$output"
        '';
      };

      recordingToggle = pkgs.writeShellApplication {
        name = "linux-desktop-recording-toggle";
        runtimeInputs = [ pkgs.systemd ];
        text = ''
          if systemctl --user --quiet is-active linux-desktop-recording.service; then
            exec systemctl --user stop linux-desktop-recording.service
          else
            exec systemctl --user start --no-block linux-desktop-recording.service
          fi
        '';
      };

      sessionCommand = pkgs.writeShellApplication {
        name = "linux-desktop-session";
        runtimeInputs = [
          pkgs.hyprland
          pkgs.systemd
        ];
        text = ''
          case "''${1:-}" in
            suspend)
              exec systemctl suspend
              ;;
            logout)
              exec hyprctl dispatch exit
              ;;
            reboot)
              exec systemctl reboot
              ;;
            poweroff)
              exec systemctl poweroff
              ;;
            *)
              printf 'Usage: linux-desktop-session {suspend|logout|reboot|poweroff}\n' >&2
              exit 2
              ;;
          esac
        '';
      };
    in
    {
      services.awww.enable = true;

      home.packages = [
        launcher
        developmentLauncher
        lockCommand
        sessionCommand
        clipboardCopy
        videoWallpaper
        wallpaperLibrary
        recordingToggle
        pkgs.quickshell
        pkgs.mpvpaper
        spectrumAnalyzer
      ];

      xdg.configFile."linux-desktop/runtime.json".source = runtimeConfig;

      systemd.user.paths.linux-desktop-wallpaper-image = {
        Unit.Description = "Reload wallpaper when the selected theme changes";
        Path.PathChanged = "%h/.config/linux-desktop";
        Install.WantedBy = [ "hyprland-session.target" ];
      };

      systemd.user.services = {
        linux-desktop-wallpaper-image = {
          Unit = {
            Description = "Apply the Stylix wallpaper with awww transitions";
            Wants = [ "awww.service" ];
            After = [
              "awww.service"
              "hyprland-session.target"
            ];
            PartOf = [ "hyprland-session.target" ];
          };

          Service = {
            Type = "oneshot";
            ExecStart = lib.getExe applyWallpaper;
            Restart = "on-failure";
            RestartSec = 2;
          };

          Install.WantedBy = [ "hyprland-session.target" ];
        };

        "linux-desktop-wallpaper-video@" = {
          Unit = {
            Description = "Selected video wallpaper on %i";
            PartOf = [ "hyprland-session.target" ];
            Wants = [ "awww.service" ];
            After = [
              "awww.service"
              "hyprland-session.target"
            ];
          };
          Service = {
            ExecStart = "${lib.getExe wallpaperVideoFromState} %i";
            Restart = "on-failure";
            RestartSec = 2;
          };
        };

        linux-desktop-spectrum = {
          Unit = {
            Description = "Hyprland desktop audio spectrum analyser";
            PartOf = [ "hyprland-session.target" ];
            After = [
              "hyprland-session.target"
              "pipewire.service"
            ];
          };

          Service = {
            ExecStart = lib.getExe spectrumAnalyzer;
            Restart = "on-failure";
            RestartSec = 1;
          };

          Install.WantedBy = [ "hyprland-session.target" ];
        };

        linux-desktop-recording = {
          Unit = {
            Description = "Record a selected Wayland screen region";
            PartOf = [ "hyprland-session.target" ];
            After = [ "hyprland-session.target" ];
          };
          Service = {
            ExecStart = lib.getExe recordRegion;
            KillSignal = "SIGINT";
            TimeoutStopSec = 15;
            Restart = "no";
          };
        };

        linux-desktop-lock = {
          Unit = {
            Description = "Hyprland desktop session lock";
            PartOf = [ "hyprland-session.target" ];
            After = [ "hyprland-session.target" ];
          };

          Service = {
            ExecStart = lib.getExe lockServiceLauncher;
            Restart = "no";
          };
        };

        linux-desktop = {
          Unit = {
            Description = "Hyprland desktop shell";
            PartOf = [ "hyprland-session.target" ];
            Wants = [ "linux-desktop-spectrum.service" ];
            After = [
              "hyprland-session.target"
              "linux-desktop-spectrum.service"
            ];
          };

          Service = {
            ExecStart = "${lib.getExe launcher} --no-duplicate";
            Restart = "on-failure";
            RestartSec = 1;
          };

          Install.WantedBy = [ "hyprland-session.target" ];
        };
      }
      // lib.optionalAttrs (scopeConfig.videoWallpaper != null) {
        linux-desktop-wallpaper = {
          Unit = {
            Description = "Hyprland desktop video wallpaper";
            PartOf = [ "hyprland-session.target" ];
            Wants = [ "awww.service" ];
            After = [
              "hyprland-session.target"
              "awww.service"
            ];
            ConditionPathExists = scopeConfig.videoWallpaper;
          };

          Service = {
            ExecStart = "${lib.getExe videoWallpaper} ${lib.escapeShellArg scopeConfig.videoWallpaper}";
            Restart = "on-failure";
            RestartSec = 2;
          };

          Install.WantedBy = [ "hyprland-session.target" ];
        };
      };
    };
}
