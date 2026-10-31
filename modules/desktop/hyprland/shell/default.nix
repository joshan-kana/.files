{
  config,
  configurationFlakeSubdirectory ? null,
  configurationName,
  configurationOutputName,
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

  # The chooser is a frontend to the canonical full-system themed output.
  themeSet = pkgs.writeShellApplication {
    name = "theme-set";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.jq
      pkgs.systemd
    ];
    text = ''
      configuredTheme=${lib.escapeShellArg configuredTheme}
      repoPath=${lib.escapeShellArg config.dotfiles.paths.repoPath}
      manifest=${lib.escapeShellArg (toString themeManifest)}
      expectedUser=${lib.escapeShellArg primaryUser}
      operationDir="''${XDG_STATE_HOME:-$HOME/.local/state}/linux-desktop/theme-operation"
      operationUnit=linux-desktop-theme-apply.scope

      set_phase() {
        mkdir -p "$operationDir"
        chmod 700 "$operationDir"
        printf '%s\n' "$1" >"$operationDir/phase"
      }

      finish_operation() {
        result=$?
        if [ "$result" -eq 0 ]; then
          set_phase completed
        elif [ "$(cat "$operationDir/phase" 2>/dev/null || :)" != cancelled ]; then
          set_phase failed
        fi
      }

      validate_theme() {
        case "$1" in
          ${lib.concatStringsSep "|" themeNames}) ;;
          *) printf 'Unknown theme: %s\n' "$1" >&2; exit 2 ;;
        esac
      }

      case "''${1:-}" in
        list)
          if [ "''${2:-}" = "--json" ]; then
            cat "$manifest"
          else
            ${lib.concatMapStringsSep "\n" (name: "printf '%s\\n' ${lib.escapeShellArg name}") themeNames}
          fi
          ;;
        current)
          printf '%s\n' "$configuredTheme"
          ;;
        status)
          phase="$(cat "$operationDir/phase" 2>/dev/null || printf idle)"
          target="$(cat "$operationDir/target" 2>/dev/null || :)"
          active=false
          if systemctl --user --quiet is-active "$operationUnit"; then active=true; fi
          jq -n --arg phase "$phase" --arg target "$target" --argjson running "$active" '{phase:$phase,target:$target,running:$running}'
          ;;
        logs)
          if [ -f "$operationDir/output.log" ]; then tail -n 12 "$operationDir/output.log" | cut -c1-150; fi
          ;;
        cancel)
          phase="$(cat "$operationDir/phase" 2>/dev/null || :)"
          if [ "$phase" != building ] && [ "$phase" != preparing ]; then
            printf 'Cancellation is only safe before authorization/activation.\n' >&2
            exit 1
          fi
          systemctl --user stop "$operationUnit"
          set_phase cancelled
          ;;
        switch)
          selected="''${2:-}"
          validate_theme "$selected"
          if [ "''${USER:-}" != "$expectedUser" ]; then
            printf 'Theme chooser is configured for user %s\n' "$expectedUser" >&2
            exit 1
          fi
          if [ "''${3:-}" != "--scoped" ]; then
            if systemctl --user --quiet is-active "$operationUnit"; then
              printf 'A theme activation is already running.\n' >&2
              exit 1
            fi
            mkdir -p "$operationDir"
            chmod 700 "$operationDir"
            printf '%s\n' "$selected" >"$operationDir/target"
            : >"$operationDir/output.log"
            chmod 600 "$operationDir/output.log" "$operationDir/target"
            set_phase preparing
            exec systemd-run --user --scope --quiet --collect --unit=linux-desktop-theme-apply --description="Apply desktop theme $selected" -- "$0" switch "$selected" --scoped
          fi
          exec >>"$operationDir/output.log" 2>&1
          trap finish_operation EXIT
          set_phase building
          printf 'Building %s...\n' "$selected"
          ${lib.getExe pkgs.nh} os build "$repoPath/themes" --hostname "${configurationName}-$selected" --diff never
          set_phase authorizing
          printf 'Requesting permission to activate %s...\n' "$selected"
          set_phase activating
          ${lib.getExe pkgs.nh} os switch "$repoPath/themes" --hostname "${configurationName}-$selected" --diff never
          printf 'Activated %s.\n' "$selected"
          ;;
        *)
          printf 'Usage: theme-set {list [--json]|current|switch <theme>|status|logs|cancel}\n' >&2
          exit 2
          ;;
      esac
    '';
  };

  windowEffectsToggle = pkgs.writeShellApplication {
    name = "linux-desktop-window-effects-toggle";
    runtimeInputs = [ pkgs.quickshell ];
    text = ''
      # The shell owns and persists this preference; never update Hyprland
      # independently of the saved state. Target its Shell ID rather than the
      # default Quickshell config, which does not exist on these hosts.
      instance=""
      candidate=""
      while IFS= read -r line; do
        case "$line" in
          "Instance "*:)
            candidate="''${line#Instance }"
            candidate="''${candidate%:}"
            ;;
          "  Shell ID: linux-desktop")
            instance="$candidate"
            break
            ;;
        esac
      done < <(quickshell list --all)
      if [ -z "$instance" ]; then
        printf 'Linux desktop shell is not running.\n' >&2
        exit 1
      fi
      quickshell ipc --id "$instance" call desktop toggleWindowEffects
    '';
  };

  resourceProbe = pkgs.writeShellApplication {
    name = "linux-desktop-resource-probe";
    text = ''
      gpu=null
      cpu_temp=null
      gpu_temp=null
      for path in /sys/class/drm/card*/device/gpu_busy_percent /sys/class/drm/card*/device/gt_busy_percent; do
        [ -r "$path" ] || continue
        IFS= read -r value < "$path" || true
        if [[ "$value" =~ ^[0-9]+$ ]] && (( value <= 100 )); then gpu="$value"; break; fi
      done
      for device in /sys/class/hwmon/hwmon*; do
        [ -r "$device/name" ] || continue
        IFS= read -r name < "$device/name" || true
        case "$name" in
          coretemp|k10temp|zenpower|cpu_thermal|soc_thermal|scmi_sensors) target=cpu ;;
          amdgpu|nouveau) target=gpu ;;
          *) continue ;;
        esac
        for path in "$device"/temp*_input; do
          [ -r "$path" ] || continue
          IFS= read -r value < "$path" || true
          if [[ "$value" =~ ^[0-9]+$ ]] && (( value <= 150000 )); then
            if [ "$target" = cpu ]; then cpu_temp="$value"; else gpu_temp="$value"; fi
            break
          fi
        done
      done
      if [ "$cpu_temp" = null ]; then
        for device in /sys/class/thermal/thermal_zone*; do
          [ -r "$device/type" ] && [ -r "$device/temp" ] || continue
          IFS= read -r name < "$device/type" || true
          case "$name" in
            x86_pkg_temp|cpu-thermal|cpu_thermal|soc_thermal|soc-thermal)
              IFS= read -r value < "$device/temp" || true
              if [[ "$value" =~ ^[0-9]+$ ]] && (( value <= 150000 )); then cpu_temp="$value"; break; fi
              ;;
          esac
        done
      fi
      printf '{"gpuPercent":%s,"cpuMilliC":%s,"gpuMilliC":%s}\n' "$gpu" "$cpu_temp" "$gpu_temp"
    '';
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

  shellVisual = {
    panelOpacity = 1.0;
    focusOpacity = 0.96;
    scrimOpacity = 0.50;
    squircleExponent = 4.5;
  };
in
{
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

      # Spatially reveal the new wallpaper rather than cross-dissolving both
      # frames. One policy covers stills, GIFs, and first-frame video posters.
      wallpaperTransitionDuration = "1.05";
      wallpaperTransition = ''
        transition_args=(
          --transition-type wave
          --transition-angle 28
          --transition-wave "24,10"
          --transition-duration ${wallpaperTransitionDuration}
          --transition-fps 120
          --transition-bezier "0.2,0,0.15,1"
        )
        if [ -f "$XDG_RUNTIME_DIR/linux-desktop-wallpaper-motion-disabled" ]; then
          transition_args=(--transition-type none)
        fi
      '';

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
              ${wallpaperTransition}
              # Resolve overrides before painting. Applying Stylix to all
              # outputs first flashes over the user's selected wallpaper.
              state_dir="''${XDG_STATE_HOME:-$HOME/.local/state}/linux-desktop/wallpapers"
              if [ ! -f "$state_dir/all.wall" ]; then
                while IFS= read -r output; do
                  [ -n "$output" ] || continue
                  if [ ! -f "$state_dir/$output.wall" ]; then
                    awww img --outputs "$output" "''${transition_args[@]}" "$wallpaper"
                  fi
                done < <(awww query | sed -n 's/^: \([^:]*\):.*/\1/p')
              fi

              # Reapply each selected output without an intermediate default.
              for entry in "$state_dir"/*.wall; do
                [ -f "$entry" ] || continue
                { IFS= read -r resize && IFS= read -r image; } < "$entry" || continue
                [ -f "$image" ] || continue
                output="$(basename "$entry" .wall)"
                args=()
                [ "$output" = all ] || args=(--outputs "$output")
                case "''${image,,}" in
                  *.mp4|*.webm|*.mkv|*.mov)
                    still="$(${lib.getExe wallpaperLibrary} thumbnail "$image")" || continue
                    awww img "''${args[@]}" --resize "$resize" --transition-type none "$still"
                    if [ -f "$quiet" ]; then
                      systemctl --user stop --no-block "linux-desktop-wallpaper-video@$output.service" || true
                    else
                      systemctl --user start --no-block "linux-desktop-wallpaper-video@$output.service"
                    fi
                    ;;
                  *)
                    still="$image"
                    if [ -f "$quiet" ] && [[ "''${image,,}" = *.gif ]]; then
                      still="$(${lib.getExe wallpaperLibrary} thumbnail "$image")" || continue
                    fi
                    awww img "''${args[@]}" --resize "$resize" "''${transition_args[@]}" "$still"
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
          library="$HOME/wallpapers"
          state_dir="''${XDG_STATE_HOME:-$HOME/.local/state}/linux-desktop/wallpapers"
          runtime="''${XDG_CONFIG_HOME:-$HOME/.config}/linux-desktop/runtime.json"
          action="''${1:-}"
          output="''${2:-all}"
          if [ "$action" = thumbnail-animated ]; then
            image="$output"
            [ -f "$image" ] && [[ "$image" = /* ]] || exit 2
            case "''${image,,}" in *.gif|*.mp4|*.webm|*.mkv|*.mov) ;; *) exit 2 ;; esac
            # The selected item alone gets a short, muted cached motion
            # preview. No decoding or background player when the gallery is
            # closed or global reduced motion is active.
            cache="''${XDG_CACHE_HOME:-$HOME/.cache}/linux-desktop/wallpaper-thumbnails"
            mkdir -p "$cache"
            key="$(printf '%s:%s' "$image" "$(stat -c '%Y:%s' "$image")" | sha256sum | cut -d' ' -f1)"
            thumb="$cache/$key-motion.gif"
            exec 9>"$cache/$key-motion.lock"
            flock 9
            if [ ! -s "$thumb" ]; then
              tmp="$(mktemp "$cache/.animated.XXXXXXXX.gif")"
              trap 'rm -f "$tmp"' EXIT
              ffmpeg -nostdin -v error -i "$image" -t 2.5 \
                -vf 'fps=8,scale=320:200:force_original_aspect_ratio=decrease:flags=fast_bilinear' \
                -loop 0 -y "$tmp"
              mv -f "$tmp" "$thumb"
            fi
            printf '%s\n' "$thumb"
            exit 0
          fi
          if [ "$action" = thumbnail ]; then
            image="$output"
            [ -f "$image" ] && [[ "$image" = /* ]] || exit 2
            # Grid cards share the video poster cache. Even stills can be
            # multi-megabyte 4K images; decode once instead of keeping full
            # resolution textures alive for every visible thumbnail.
            cache="''${XDG_CACHE_HOME:-$HOME/.cache}/linux-desktop/wallpaper-thumbnails"
            mkdir -p "$cache"
            key="$(printf '%s:%s' "$image" "$(stat -c '%Y:%s' "$image")" | sha256sum | cut -d' ' -f1)"
            thumb="$cache/$key.png"
            exec 8>"$cache/$key.lock"
            flock 8
            if [ ! -s "$thumb" ]; then
              tmp="$(mktemp "$cache/.thumb.XXXXXXXX.png")"
              trap 'rm -f "$tmp"' EXIT
              ffmpeg -nostdin -v error -i "$image" -frames:v 1 -vf 'scale=380:250:force_original_aspect_ratio=decrease' -update 1 -y "$tmp"
              mv -f "$tmp" "$thumb"
            fi
            printf '%s\n' "$thumb"
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
            # Static selections don't change when animation is toggled.
            # Only animated wallpapers need reconfiguration to a still/video.
            for selection in "$state_dir"/*.wall; do
              [ -f "$selection" ] || continue
              image="$(tail -n 1 "$selection")"
              case "''${image,,}" in
                *.gif|*.mp4|*.webm|*.mkv|*.mov)
                  systemctl --user start --no-block linux-desktop-wallpaper-image.service
                  break
                  ;;
              esac
            done
            exit 0
          fi

          case "$action" in
            list)
              if [ -d "$library" ]; then
                # The personal library can be a directory symlink into a
                # mounted share (e.g. Parallels' Dropbox mapping). Follow
                # only the supplied root symlink, not arbitrary nested links.
                find -H "$library" -type f \(                   -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' -o                   -iname '*.webp' -o -iname '*.bmp' -o -iname '*.gif' -o -iname '*.mp4' -o -iname '*.webm' -o -iname '*.mkv' -o -iname '*.mov' \) -print                   | LC_ALL=C sort | jq -Rsc '[split("\n")[] | select(length > 0)]'
              else
                printf '[]\n'
              fi
              ;;
            current)
              # An all-output override also applies to screens that have no
              # more-specific override. Report the effective wallpaper, not
              # the Stylix default hidden beneath an active all-output image.
              current_file="$state_file"
              if [ ! -f "$current_file" ] && [ "$output" != all ]; then
                current_file="$state_dir/all.wall"
              fi
              if [ -f "$current_file" ]; then
                { IFS= read -r resize && IFS= read -r image; } < "$current_file" || exit 1
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
              ${wallpaperTransition}
              unit="linux-desktop-wallpaper-video@$output.service"
              args=()
              [ "$output" = all ] || args=(--outputs "$output")
              previous_file="$state_dir/$output.wall"
              [ -f "$previous_file" ] || previous_file="$state_dir/all.wall"
              if [ -f "$previous_file" ]; then
                previous="$(tail -n 1 "$previous_file")"
                case "''${previous,,}" in
                  *.mp4|*.webm|*.mkv|*.mov)
                    # The video layer covers the image layer. Retain its poster
                    # before stopping it, so the next image has a visible old frame.
                    previous_poster="$($0 thumbnail "$previous")"
                    awww img "''${args[@]}" --resize "$resize" --transition-type none "$previous_poster"
                    ;;
                esac
              fi
              if [ "$kind" = video ]; then
                ffprobe -v error -select_streams v:0 -show_entries stream=codec_type -of csv=p=0 "$image" | grep -qx video || exit 2
                still="$($0 thumbnail "$image")"
              else
                still="$image"
                if [ -f "$XDG_RUNTIME_DIR/linux-desktop-wallpaper-motion-disabled" ] && [[ "''${image,,}" = *.gif ]]; then
                  still="$($0 thumbnail "$image")"
                fi
              fi
              systemctl --user stop "$unit" || true
              awww img "''${args[@]}" --resize "$resize" "''${transition_args[@]}" "$still"
              mkdir -p "$state_dir"
              temp="$(mktemp "$state_dir/.wallpaper.XXXXXXXX")"
              trap 'rm -f "$temp"' EXIT
              printf '%s\n%s\n' "$resize" "$image" > "$temp"
              mv -f "$temp" "$state_file"
              if [ "$kind" = video ]; then
                if [ ! -f "$XDG_RUNTIME_DIR/linux-desktop-wallpaper-motion-disabled" ]; then
                  # Let the eased poster transition finish before playing the
                  # same first frame as video, avoiding an abrupt hard swap.
                  sleep ${wallpaperTransitionDuration}
                fi
                systemctl --user restart "$unit"
              fi
              ;;
            reset)
              systemctl --user stop "linux-desktop-wallpaper-video@$output.service" || true
              rm -f "$state_file"
              systemctl --user start --no-block linux-desktop-wallpaper-image.service
              ;;
            *)
              printf 'Usage: linux-desktop-wallpaper-library {list|current [output]|set output crop\|fit /abs/file|reset [output]|thumbnail /abs/file|thumbnail-animated /abs/file|motion on\|off}\n' >&2
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
          exec mpvpaper -p -a full -l background -o "$options" "$output" "$video"
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

          mpvpaper -l background -o "$mpvOptions" '*' "$1"
        '';
      };

      # The subscribed iCal URL is a runtime-only secret. Google Calendar
      # publishes a standard VCALENDAR feed; khal already owns local event UI.
      agendaIcalSource = pkgs.writeText "linux-desktop-ical-sync.py" ''
        import hashlib
        import os
        import re
        import stat
        import sys
        import tempfile
        import urllib.parse
        import urllib.request
        from pathlib import Path

        from icalendar import Calendar

        MAX_FEED_BYTES = 12 * 1024 * 1024
        PREFIX = "google-ical-"
        FEED_DIRECTORY = "calendar-icals"
        LEGACY_FILENAME = "calendar-ical-url"


        class HttpsRedirects(urllib.request.HTTPRedirectHandler):
            def redirect_request(self, req, fp, code, msg, headers, url):
                if urllib.parse.urlsplit(url).scheme != "https":
                    raise ValueError("insecure calendar redirect")
                return super().redirect_request(req, fp, code, msg, headers, url)


        def sources():
            private_root = Path.home() / ".secrets"
            legacy = private_root / LEGACY_FILENAME
            if legacy.exists() or legacy.is_symlink():
                yield "legacy", legacy
            directory = private_root / FEED_DIRECTORY
            if not directory.exists() and not directory.is_symlink():
                return
            if directory.is_symlink() or not directory.is_dir():
                raise ValueError("invalid calendar directory")
            if stat.S_IMODE(directory.stat().st_mode) & 0o077:
                raise ValueError("calendar directory must be private")
            for entry in sorted(directory.iterdir()):
                if entry.name.endswith(".url"):
                    yield "file:" + entry.name, entry


        def read_feed(source_file):
            if source_file.is_symlink() or not source_file.is_file():
                raise ValueError("calendar source must be a regular file")
            if stat.S_IMODE(source_file.stat().st_mode) & 0o077:
                raise ValueError("calendar source must be private")
            url = source_file.read_text(encoding="utf-8").strip()
            parsed = urllib.parse.urlsplit(url)
            if parsed.scheme != "https" or not parsed.hostname:
                raise ValueError("calendar URL must use HTTPS")
            opener = urllib.request.build_opener(HttpsRedirects())
            with opener.open(urllib.request.Request(url), timeout=18) as response:
                if urllib.parse.urlsplit(response.geturl()).scheme != "https":
                    raise ValueError("insecure calendar redirect")
                data = response.read(MAX_FEED_BYTES + 1)
            if len(data) > MAX_FEED_BYTES:
                raise ValueError("calendar feed too large")
            return data


        def namespace_for(source):
            return PREFIX + hashlib.sha256(source.encode("utf-8")).hexdigest()[:24] + "--"


        def split_events(data, namespace=PREFIX):
            if not data.strip().startswith(b"BEGIN:VCALENDAR") or b"END:VCALENDAR" not in data:
                raise ValueError("not an iCalendar feed")
            feed = Calendar.from_ical(data)
            if str(feed.get("VERSION", "")) != "2.0":
                raise ValueError("unsupported calendar version")
            zones = [entry for entry in feed.subcomponents if entry.name == "VTIMEZONE"]
            events = {}
            event_count = 0
            for entry in feed.subcomponents:
                if entry.name != "VEVENT":
                    continue
                uid = str(entry.get("UID", "")).strip()
                if not uid:
                    raise ValueError("calendar event without UID")
                events.setdefault(uid, []).append(entry)
                event_count += 1
                if event_count > 40000:
                    raise ValueError("too many calendar events")
            files = {}
            for uid, entries in events.items():
                item = Calendar()
                item.add("VERSION", "2.0")
                item.add("PRODID", "-//linux-desktop//local iCalendar subscription//")
                for zone in zones:
                    item.add_component(zone)
                for event in entries:
                    item.add_component(event)
                name = namespace + hashlib.sha256(uid.encode("utf-8")).hexdigest() + ".ics"
                files[name] = item.to_ical()
            return files


        def sync_files(files, namespace=PREFIX):
            base = Path(os.environ.get("XDG_DATA_HOME", str(Path.home() / ".local/share"))) / "calendars" / "personal"
            if base.is_symlink():
                raise ValueError("calendar directory cannot be a symlink")
            base.mkdir(parents=True, exist_ok=True, mode=0o700)
            staged = []
            try:
                for name, data in files.items():
                    fd, filename = tempfile.mkstemp(prefix=".ical-stage-", dir=base)
                    staged.append((Path(filename), base / name))
                    with os.fdopen(fd, "wb") as destination:
                        destination.write(data)
                    os.chmod(filename, 0o600)
                for tmp, destination in staged:
                    os.replace(tmp, destination)
                existing = set(files)
                for path in base.glob(namespace + "*.ics"):
                    if path.name not in existing and path.is_file() and not path.is_symlink():
                        path.unlink()
            finally:
                for temporary, _ in staged:
                    temporary.unlink(missing_ok=True)


        def main():
            try:
                feed_sources = list(sources())
            except Exception:
                print("iCalendar source configuration invalid", file=sys.stderr)
                return 1
            failed = 0
            for source, path in feed_sources:
                try:
                    namespace = namespace_for(source)
                    files = split_events(read_feed(path), namespace)
                    sync_files(files, namespace)
                    if source == "legacy":
                        # The original single-feed format lacked a source
                        # namespace. Retire only its 64-hex-name files after
                        # the legacy feed is successfully imported.
                        base = Path(os.environ.get("XDG_DATA_HOME", str(Path.home() / ".local/share"))) / "calendars" / "personal"
                        for old in base.glob(PREFIX + "*.ics"):
                            suffix = old.name[len(PREFIX):-4]
                            if len(suffix) == 64 and all(c in "0123456789abcdef" for c in suffix):
                                if old.is_file() and not old.is_symlink():
                                    old.unlink()
                except Exception:
                    failed += 1
            directory = Path.home() / ".secrets" / FEED_DIRECTORY
            if directory.is_dir() and not directory.is_symlink():
                # Removing or renaming a .url file intentionally removes only
                # that source's previously imported events. When the private
                # source directory itself is unavailable, retain all caches.
                active_namespaces = {namespace_for(source) for source, _ in feed_sources}
                base = Path(os.environ.get("XDG_DATA_HOME", str(Path.home() / ".local/share"))) / "calendars" / "personal"
                if base.is_dir() and not base.is_symlink():
                    for cached in base.glob(PREFIX + "*.ics"):
                        if not re.fullmatch(r"google-ical-[0-9a-f]{24}--[0-9a-f]{64}\.ics", cached.name):
                            continue
                        if not any(cached.name.startswith(name) for name in active_namespaces):
                            if cached.is_file() and not cached.is_symlink():
                                cached.unlink()
            if failed:
                # Do not write private feed URLs or event titles to the journal.
                print("iCalendar refresh failed for " + str(failed) + " source(s); cached events retained", file=sys.stderr)
            return 1 if failed else 0


        if __name__ == "__main__":
            sys.exit(main())
      '';

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
        text = ''
          configRoot="''${XDG_CONFIG_HOME:-$HOME/.config}/khal"
          dataRoot="''${XDG_DATA_HOME:-$HOME/.local/share}/calendars/personal"
          configFile="$configRoot/config"
          if [ -e "$configFile" ]; then
            printf 'Existing khal configuration preserved: %s\n' "$configFile"
            exit 0
          fi
          mkdir -p "$configRoot" "$dataRoot"
          cat > "$configFile" <<EOF
          [calendars]
          [[personal]]
          path = $dataRoot
          type = calendar

          [default]
          default_calendar = personal

          [locale]
          timeformat = %H:%M
          dateformat = %Y-%m-%d
          longdateformat = %Y-%m-%d
          datetimeformat = %Y-%m-%d %H:%M
          longdatetimeformat = %Y-%m-%d %H:%M
          EOF
        '';
      };

      agendaQuerySource = pkgs.writeText "linux-desktop-agenda-query.py" ''
        import hashlib
        import json
        import os
        import re
        import subprocess
        import sys
        import tempfile
        from pathlib import Path

        HOME = Path.home()
        CONFIG = Path(os.environ.get("XDG_CONFIG_HOME", str(HOME / ".config")))
        DATA = Path(os.environ.get("XDG_DATA_HOME", str(HOME / ".local/share")))
        SOURCES = HOME / ".secrets/calendar-icals"
        CACHE = DATA / "calendars/personal"
        SETTINGS = CONFIG / "linux-desktop/calendar-visibility.json"
        EVENT_FILENAME = re.compile(r"^google-ical-([a-f0-9]{24})--([a-f0-9]{64})\.ics$")
        DATE = re.compile(r"^[0-9]{4}-[0-9]{2}-[0-9]{2}$")


        def calendars():
            feeds = []
            if SOURCES.is_dir() and not SOURCES.is_symlink():
                for path in sorted(SOURCES.glob("*.url")):
                    if path.is_file() and not path.is_symlink():
                        key = hashlib.sha256(("file:" + path.name).encode()).hexdigest()[:24]
                        feeds.append({"id": key, "name": path.stem})
            legacy = HOME / ".secrets/calendar-ical-url"
            if legacy.is_file() and not legacy.is_symlink():
                feeds.append({"id": hashlib.sha256(b"legacy").hexdigest()[:24], "name": "Calendar"})
            return feeds


        def disabled_ids():
            if not SETTINGS.is_file() or SETTINGS.is_symlink():
                return set()
            try:
                contents = json.loads(SETTINGS.read_text(encoding="utf-8"))
                return set(value for value in contents.get("disabled", []) if isinstance(value, str))
            except (ValueError, OSError, AttributeError, TypeError):
                return set()


        def set_enabled(source, enabled):
            if source not in {item["id"] for item in calendars()}:
                raise ValueError("unknown calendar source")
            disabled = disabled_ids()
            if enabled:
                disabled.discard(source)
            else:
                disabled.add(source)
            SETTINGS.parent.mkdir(parents=True, exist_ok=True)
            fd, temporary = tempfile.mkstemp(prefix=".calendar-visibility-", dir=SETTINGS.parent)
            try:
                with os.fdopen(fd, "w", encoding="utf-8") as stream:
                    json.dump({"disabled": sorted(disabled)}, stream)
                os.chmod(temporary, 0o600)
                os.replace(temporary, SETTINGS)
            finally:
                Path(temporary).unlink(missing_ok=True)


        def read_index():
            # The importer namespaces each file by source and hashes its UID.
            # Resolve khal's recurring instances without reparsing every ICS.
            index = {}
            if CACHE.is_dir():
                for path in CACHE.glob("google-ical-*.ics"):
                    match = EVENT_FILENAME.fullmatch(path.name)
                    if match:
                        index.setdefault(match.group(2), set()).add(match.group(1))
            return index


        def agenda(start):
            feeds = calendars()
            disabled = disabled_ids()
            selected = [{"id": feed["id"], "name": feed["name"], "enabled": feed["id"] not in disabled}
                        for feed in feeds]
            if not (CONFIG / "khal/config").is_file():
                return {"configured": False, "calendars": selected, "events": []}
            from datetime import date, timedelta
            last_day = date.fromisoformat(start) + timedelta(days=6)
            end = last_day.isoformat()
            args = ["khal", "list", "--json", "uid", "--json", "title", "--json", "start-date",
                    "--json", "start-time", "--json", "end-date", "--json", "end-time",
                    "--json", "location", start, end]
            output = subprocess.run(args, capture_output=True, text=True, check=True).stdout
            index = read_index()
            known = {feed["id"]: feed["name"] for feed in feeds}
            events = []
            for line in output.splitlines():
                if not line.strip():
                    continue
                for event in json.loads(line):
                    uid_hash = hashlib.sha256(str(event.get("uid", "")).encode()).hexdigest()
                    origins = index.get(uid_hash, set())
                    if origins and not any(source in known and source not in disabled for source in origins):
                        continue
                    event_start = event.get("start-date", "")
                    event_end = event.get("end-date", "")
                    if event_start > end:
                        continue
                    carried = event_start < start
                    display_date = event_start
                    display_time = event.get("start-time", "")
                    if carried:
                        if not event_end:
                            continue
                        # Khal also includes events spanning the entire week.
                        # Do not put month-old starting dates before this week's
                        # appointments. Include carryovers only when they end
                        # within the selected week.
                        finish = date.fromisoformat(event_end)
                        if not event.get("start-time") and not event.get("end-time"):
                            finish -= timedelta(days=1)  # all-day end is exclusive
                        if not date.fromisoformat(start) <= finish <= last_day:
                            continue
                        display_date = finish.isoformat()
                        display_time = event.get("end-time", "")
                    source = next((known[item] for item in sorted(origins) if item in known), "Local")
                    events.append({
                        "calendar": source,
                        "date": display_date,
                        "time": display_time,
                        "dateKind": "ENDS" if carried else "",
                        "endTime": event.get("end-time", ""),
                        "title": event.get("title", ""),
                        "location": event.get("location", "") or "",
                    })
            events.sort(key=lambda entry: (entry["date"], entry["time"], entry["title"]))
            return {"configured": True, "calendars": selected, "events": events}


        def main():
            if len(sys.argv) == 4 and sys.argv[1] == "--set-enabled" and sys.argv[3] in ("true", "false"):
                set_enabled(sys.argv[2], sys.argv[3] == "true")
                return
            if len(sys.argv) != 2 or not DATE.fullmatch(sys.argv[1]):
                raise ValueError("usage: linux-desktop-agenda-query YYYY-MM-DD")
            print(json.dumps(agenda(sys.argv[1])))


        if __name__ == "__main__":
            try:
                main()
            except Exception:
                # Never print private event contents or feed URLs to journald.
                print("Calendar query failed", file=sys.stderr)
                sys.exit(1)
      '';

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
        text = ''
          action="''${1:-}"
          id="''${2:-}"
          private_dir="''${XDG_RUNTIME_DIR:?}/linux-desktop-clipboard"
          case "$action" in
            clear)
              # The thumbnails are disposable previews, never a second store.
              rm -rf -- "$private_dir"
              ;;
            image)
              [[ "$id" =~ ^[0-9]+$ ]] || exit 2
              umask 077
              mkdir -p -- "$private_dir"
              chmod 700 -- "$private_dir"
              # Only one thumbnail is ever retained; frequent J/K navigation
              # must not leave a growing set of decoded private images behind.
              find "$private_dir" -maxdepth 1 -type f -name 'preview-*.png' -delete
              tmp="$(mktemp "$private_dir/preview-XXXXXXXX.png")"
              trap 'rm -f -- "$tmp"' EXIT
              if cliphist decode "$id" | magick \
                -limit memory 96MiB -limit map 192MiB \
                -limit width 8192 -limit height 8192 \
                - -auto-orient -thumbnail '520x340>' -strip "png:$tmp"; then
                printf '%s\n' "$tmp"
                # QML removes all thumbnail files on panel dismissal.
                trap - EXIT
              else
                exit 1
              fi
              ;;
            *) exit 2 ;;
          esac
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
          accentSecondary = colors.base0E;
          accentTertiary = colors.base0C;
          accentWarm = colors.base09;
          accentWorkspace = colors.base0D;
          accentUtility = colors.base0F;
          accentEnergy = colors.base0A;
          accentNature = colors.base0B;
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
          themeSet = lib.getExe themeSet;
          urlOpen = lib.getExe' pkgs.xdg-utils "xdg-open";
          paletteSearch = lib.getExe paletteSearch;
          clipboardPaste = lib.getExe' pkgs.wl-clipboard "wl-paste";
          wallpaperLibrary = lib.getExe wallpaperLibrary;
          recordingToggle = lib.getExe recordingToggle;
          recordingLibrary = lib.getExe recordingLibrary;
          notificationOpen = lib.getExe notificationOpen;
          frozenCapture = lib.getExe frozenCapture;
          colourPicker = lib.getExe colourPicker;
          nightLightControl = lib.getExe nightLightControl;
        };

        wallpaper = toString osConfig.stylix.image;
      };

      launcher = pkgs.writeShellApplication {
        name = "linux-desktop";
        runtimeInputs = [ pkgs.quickshell ];
        text = ''
          export LINUX_DESKTOP_RUNTIME="''${XDG_CONFIG_HOME:-$HOME/.config}/linux-desktop/runtime.json"
          exec qs --path "${productionShellPath}" "$@"
        '';
      };

      developmentLauncher = pkgs.writeShellApplication {
        name = "linux-desktop-dev";
        runtimeInputs = [ pkgs.quickshell ];
        text = ''
          export LINUX_DESKTOP_RUNTIME="''${XDG_CONFIG_HOME:-$HOME/.config}/linux-desktop/runtime.json"
          exec qs --path ${lib.escapeShellArg developmentShellPath} "$@"
        '';
      };

      lockServiceLauncher = pkgs.writeShellApplication {
        name = "linux-desktop-lock-shell";
        runtimeInputs = [ pkgs.quickshell ];
        text = ''
          export LINUX_DESKTOP_RUNTIME="''${XDG_CONFIG_HOME:-$HOME/.config}/linux-desktop/runtime.json"
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

      nightLightControl = pkgs.writeShellApplication {
        name = "linux-desktop-night-light";
        runtimeInputs = [
          pkgs.coreutils
          pkgs.systemd
          pkgs.hyprsunset
        ];
        text = ''
          set -euo pipefail
          state_dir="''${XDG_STATE_HOME:-$HOME/.local/state}/linux-desktop"
          state_file="$state_dir/night-light"
          mode=off
          temperature=4500
          if [ -r "$state_file" ]; then
            read -r mode temperature < "$state_file" || true
          fi
          case "$mode" in off|manual|auto) ;; *) mode=off ;; esac
          if ! [[ "$temperature" =~ ^[0-9]+$ ]]; then temperature=4500; fi
          if (( temperature < 2500 || temperature > 6500 )); then
            temperature=4500
          fi
          persist() {
            mkdir -p "$state_dir"
            temp_state="$(mktemp --tmpdir="$state_dir" night-light-XXXXXXXX)"
            printf '%s %s\n' "$mode" "$temperature" > "$temp_state"
            chmod 600 "$temp_state"
            mv -f "$temp_state" "$state_file"
          }
          # Preserve the current effective state when migrating an older
          # automatic schedule to manual-only control.
          if [ "$mode" = auto ]; then
            hour="$(date +%H)"
            if (( 10#$hour >= 19 || 10#$hour < 7 )); then
              mode=manual
            else
              mode=off
            fi
            persist
          fi
          should_run() {
            [ "$mode" = manual ]
          }
          apply() {
            if should_run; then
              systemctl --user restart linux-desktop-night-light.service
            else
              systemctl --user stop linux-desktop-night-light.service
            fi
          }
          case "''${1:-state}" in
            state)
              active=false
              if systemctl --user --quiet is-active linux-desktop-night-light.service; then active=true; fi
              printf '{"mode":"%s","temperature":%s,"active":%s,"supported":true}\n' "$mode" "$temperature" "$active"
              ;;
            run)
              exec hyprsunset --temperature "$temperature"
              ;;
            apply)
              apply
              ;;
            toggle)
              if [ "$mode" = manual ]; then mode=off; else mode=manual; fi
              persist
              apply
              ;;
            set)
              [ "$#" -eq 2 ] && [[ "$2" =~ ^[0-9]+$ ]] || exit 2
              temperature="$2"
              (( temperature >= 2500 && temperature <= 6500 )) || exit 2
              persist
              if should_run; then apply; fi
              ;;
            warmer|cooler)
              if [ "$1" = warmer ]; then temperature=$((temperature - 500)); else temperature=$((temperature + 500)); fi
              temperature=$((temperature < 2500 ? 2500 : temperature > 6500 ? 6500 : temperature))
              persist
              if should_run; then apply; fi
              ;;
            *)
              printf 'Usage: linux-desktop-night-light {state|run|apply|toggle|set K|warmer|cooler}\n' >&2
              exit 2
              ;;
          esac
        '';
      };

      colourPicker = pkgs.writeShellApplication {
        name = "linux-desktop-pick-colour";
        runtimeInputs = [
          pkgs.hyprpicker
          pkgs.wl-clipboard
          pkgs.libnotify
          pkgs.systemd
        ];
        text = ''
          # Native autocopy loses ownership when the transient action exits.
          # A separate clipboard scope keeps the selected text pasteable until
          # another app replaces it, without any permanently running service.
          selected="$(hyprpicker --format=hex --no-fancy)" || exit 0
          if ! [[ "$selected" =~ ^#[[:xdigit:]]{6}$ ]]; then
            printf 'Unexpected colour picker result\n' >&2
            exit 1
          fi
          # shellcheck disable=SC2016
          systemd-run --user --scope --quiet -- \
            ${lib.getExe pkgs.bash} -c 'printf "%s" "$1" | wl-copy --type text/plain' colour-picker-copy "$selected"
          notify-send --app-name=linux-desktop "Colour copied" "$selected"
        '';
      };

      recordRegion = pkgs.writeShellApplication {
        name = "linux-desktop-record-region";
        runtimeInputs = [
          pkgs.coreutils
          pkgs.slurp
          pkgs.wf-recorder
          pkgs.pulseaudio
        ];
        text = ''
          settings="''${XDG_RUNTIME_DIR:?}/linux-desktop-recording.conf"
          if [ -f "$settings" ]; then
            { IFS= read -r output && IFS= read -r geometry && IFS= read -r audio; } < "$settings" || exit 2
            rm -f -- "$settings"
            [[ "$output" =~ ^[a-zA-Z0-9_.-]+$ ]] || exit 2
            [[ "$geometry" =~ ^-?[0-9]+,-?[0-9]+\ [0-9]+x[0-9]+$ ]] || exit 2
            case "$audio" in none|system|microphone) ;; *) exit 2 ;; esac
            args=(--output "$output")
          else
            # Explicit live-select alternative for callers outside the hub.
            geometry="$(slurp -d)" || exit 0
            audio=none
            args=()
          fi
          [ -n "$geometry" ] || exit 0
          directory="''${LINUX_DESKTOP_RECORDING_DIR:-$HOME/Videos/Screencasts}"
          mkdir -p "$directory"
          output="$directory/Recording-$(date +%Y%m%d-%H%M%S)-$$.mp4"
          case "$audio" in
            system)
              sink="$(pactl get-default-sink)"
              [ -n "$sink" ] || exit 2
              args+=("--audio=''${sink}.monitor")
              ;;
            microphone)
              source="$(pactl get-default-source)"
              [ -n "$source" ] || exit 2
              args+=("--audio=$source")
              ;;
          esac
          printf 'recording\n%s\n%s\n' "$(date +%s)" "$output" > "''${XDG_RUNTIME_DIR:?}/linux-desktop-recording.state"
          exec wf-recorder "''${args[@]}" --geometry "$geometry" --file "$output"
        '';
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
        text = ''
          [ "$#" -le 1 ] || exit 2
          if [ "$#" -eq 0 ]; then
            selected="$(kdialog --getopenfilename "$HOME/Pictures" 'Images (*.png *.jpg *.jpeg *.webp *.bmp *.gif)' )" || exit 0
            [ -n "$selected" ] || exit 0
            set -- "$selected"
          fi
          [ -f "$1" ] && [ -r "$1" ] || exit 2
          case "$(file --brief --mime-type -- "$1")" in image/*) ;; *) exit 2 ;; esac
          umask 077
          dest="''${XDG_PICTURES_DIR:-$HOME/Pictures}/Screenshots"
          mkdir -p -- "$dest"
          output="$dest/Screenshot-$(date +%Y%m%d-%H%M%S)-$$.png"
          exec satty --filename "$1" --output-filename "$output" \
            --copy-command wl-copy --initial-tool arrow --no-window-decoration \
            --font-family ${lib.escapeShellArg config.stylix.fonts.monospace.name} \
            --save-after-copy --actions-on-enter save-to-clipboard \
            --actions-on-escape exit --early-exit all
        '';
      };

      frozenCapture = pkgs.writeShellApplication {
        name = "linux-desktop-frozen-capture";
        runtimeInputs = [
          pkgs.grim
          pkgs.imagemagick
          pkgs.coreutils
          pkgs.wl-clipboard
          pkgs.libnotify
          pkgs.satty
        ];
        text = ''
          mode="''${1:-}"
          private_dir="''${XDG_RUNTIME_DIR:?}"
          ensure_snapshot() {
            [[ "$1" == "$private_dir"/linux-desktop-capture-*.png ]] && [ -f "$1" ] && [ ! -L "$1" ]
          }
          case "$mode" in
            snapshot)
              [ "$#" -eq 2 ] && [ -n "$2" ] || exit 2
              umask 077
              snapshot="$(mktemp "$private_dir/linux-desktop-capture-XXXXXXXX.png")"
              if grim -o "$2" "$snapshot"; then printf '%s\n' "$snapshot"; else rm -f -- "$snapshot"; exit 1; fi
              ;;
            clear)
              [ "$#" -eq 2 ] && ensure_snapshot "$2" || exit 2
              rm -f -- "$2"
              ;;
            copy|save|annotate)
              [ "$#" -eq 6 ] && ensure_snapshot "$2" || exit 2
              for number in "$3" "$4" "$5" "$6"; do [[ "$number" =~ ^[0-9]+$ ]] || exit 2; done
              x="$3"; y="$4"; w="$5"; h="$6"
              [ "$w" -gt 0 ] && [ "$h" -gt 0 ] || exit 2
              read -r full_width full_height < <(magick identify -format '%w %h\n' "$2")
              [ "$((x + w))" -le "$full_width" ] && [ "$((y + h))" -le "$full_height" ] || exit 2
              # Preserve the frozen frame on export failure so Enter can retry.
              geometry="''${w}x''${h}+''${x}+''${y}"
              umask 077
              dest="''${XDG_PICTURES_DIR:-$HOME/Pictures}/Screenshots"
              mkdir -p -- "$dest"
              output="$dest/Screenshot-$(date +%Y%m%d-%H%M%S)-$$.png"
              magick "$2" -crop "$geometry" +repage -strip "$output"
              if [ "$mode" = copy ]; then
                wl-copy --type image/png < "$output"
              fi
              notify-send --app-name=linux-desktop "Screenshot saved" "$output" || true
              if [ "$mode" = annotate ]; then
                ${lib.getExe imageMarkup} "$output"
              fi
              printf '%s\n' "$output"
              # Keep the source available for retry if either export fails.
              rm -f -- "$2"
              ;;
            *) exit 2 ;;
          esac
        '';
      };

      recordingToggle = pkgs.writeShellApplication {
        name = "linux-desktop-recording-toggle";
        runtimeInputs = [
          pkgs.systemd
          pkgs.coreutils
        ];
        text = ''
          service=linux-desktop-recording.service
          case "''${1:-status}" in
            status)
              if systemctl --user --quiet is-active "$service"; then echo active; else echo inactive; fi
              ;;
            stop)
              state="''${XDG_RUNTIME_DIR:?}/linux-desktop-recording.state"
              if systemctl --user --quiet is-active "$service"; then
                if [ -r "$state" ]; then
                  { IFS= read -r previous && IFS= read -r started && IFS= read -r savedPath; } < "$state" || true
                  if [[ "$previous" == recording || "$previous" == finalising ]] && [ -n "''${started:-}" ] && [ -n "''${savedPath:-}" ]; then
                    printf 'finalising\n%s\n%s\n' "$started" "$savedPath" > "$state"
                  fi
                fi
                systemctl --user stop "$service"
              fi
              rm -f -- "''${XDG_RUNTIME_DIR:?}/linux-desktop-recording.conf"
              ;;
            start)
              [ "$#" -eq 4 ] || exit 2
              [[ "$2" =~ ^[a-zA-Z0-9_.-]+$ ]] || exit 2
              [[ "$3" =~ ^-?[0-9]+,-?[0-9]+\ [0-9]+x[0-9]+$ ]] || exit 2
              case "$4" in none|system|microphone) ;; *) exit 2 ;; esac
              if systemctl --user --quiet is-active "$service"; then exit 3; fi
              umask 077
              config="''${XDG_RUNTIME_DIR:?}/linux-desktop-recording.conf"
              temp="$(mktemp "''${XDG_RUNTIME_DIR:?}/.linux-desktop-recording.XXXXXXXX")"
              printf '%s\n%s\n%s\n' "$2" "$3" "$4" > "$temp"
              mv -f -- "$temp" "$config"
              if ! systemctl --user start --no-block "$service"; then
                rm -f -- "$config"
                exit 1
              fi
              ;;
            *) exit 2 ;;
          esac
        '';
      };

      notificationOpen = pkgs.writeShellApplication {
        name = "linux-desktop-open-capture";
        runtimeInputs = [
          pkgs.xdg-utils
          pkgs.losslesscut
        ];
        text = ''
          [ "$#" -eq 2 ] || exit 2
          case "$1" in
            screenshot|edit-screenshot)
              path="$2"
              name="''${path##*/}"
              dir="''${XDG_PICTURES_DIR:-$HOME/Pictures}/Screenshots"
              [[ "$name" =~ ^Screenshot-[0-9]{8}-[0-9]{6}-[0-9]+\.png$ ]] || exit 2
              [[ "$path" == "$dir/$name" ]] || exit 2
              ;;
            recording|edit-recording)
              name="$2"
              [[ "$name" =~ ^Recording-[0-9]{8}-[0-9]{6}-[0-9]+\.mp4$ ]] || exit 2
              path="$HOME/Videos/Screencasts/$name"
              ;;
            *) exit 2 ;;
          esac
          [ -f "$path" ] && [ ! -L "$path" ] || exit 1
          case "$1" in
            edit-screenshot) exec ${lib.getExe imageMarkup} "$path" ;;
            edit-recording) exec losslesscut --disable-networking "$path" ;;
          esac
          exec xdg-open "$path"
        '';
      };

      recordingLibrary = pkgs.writeShellApplication {
        name = "linux-desktop-recordings";
        runtimeInputs = [
          pkgs.coreutils
          pkgs.findutils
          pkgs.glib
          pkgs.ffmpeg
          pkgs.gnused
          pkgs.xdg-utils
          pkgs.losslesscut
          pkgs.wl-clipboard
        ];
        text = ''
          action="''${1:-}"
          recordings="$HOME/Videos/Screencasts"
          preview_dir="''${XDG_RUNTIME_DIR:?}/linux-desktop-recordings-preview"
          case "$action" in
            list)
              umask 077
              metadata_dir="''${XDG_RUNTIME_DIR:?}/linux-desktop-recordings-metadata"
              [ ! -L "$metadata_dir" ] || exit 2
              mkdir -p -- "$metadata_dir"
              chmod 700 -- "$metadata_dir"
              {
                if [ -d "$recordings" ]; then
                  while IFS=$'\t' read -r modified name size; do
                    [[ "$name" =~ ^Recording-[0-9]{8}-[0-9]{6}-[0-9]+\.mp4$ ]] || continue
                    path="$recordings/$name"
                    [ -f "$path" ] && [ ! -L "$path" ] || continue
                    key="$(printf '%s|%s|%s' "$name" "$modified" "$size" | sha256sum | cut -d' ' -f1)"
                    metadata="$metadata_dir/$key"
                    if [ ! -s "$metadata" ]; then
                      duration="$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$path" || true)"
                      [[ "$duration" =~ ^[0-9]+(\.[0-9]+)?$ ]] || duration=0
                      tmp="$(mktemp "$metadata_dir/.duration-XXXXXXXX")"
                      printf '%s\n' "$duration" > "$tmp"
                      mv -- "$tmp" "$metadata"
                    fi
                    read -r duration < "$metadata"
                    printf '%s\t%s\t%s\t%s\n' "$modified" "$name" "$size" "$duration"
                  done < <(find "$recordings" -maxdepth 1 -type f -regextype posix-extended \
                    -regex '.*/Recording-[0-9]{8}-[0-9]{6}-[0-9]+\.mp4' -printf '%T@\t%f\t%s\n')
                fi
                screenshots="''${XDG_PICTURES_DIR:-$HOME/Pictures}/Screenshots"
                if [ -d "$screenshots" ]; then
                  while IFS=$'\t' read -r modified name size; do
                    [[ "$name" =~ ^Screenshot-[0-9]{8}-[0-9]{6}-[0-9]+\.png$ ]] || continue
                    printf '%s\t%s\t%s\t0\n' "$modified" "$name" "$size"
                  done < <(find "$screenshots" -maxdepth 1 -type f -regextype posix-extended \
                    -regex '.*/Screenshot-[0-9]{8}-[0-9]{6}-[0-9]+\.png' -printf '%T@\t%f\t%s\n')
                fi
              } | sort -rn | sed -n '1,100p'
              ;;
            clear-preview)
              [ ! -L "$preview_dir" ] || exit 2
              rm -rf -- "$preview_dir"
              ;;
            preview|open|edit|copy|trash)
              [ "$#" -eq 2 ] || exit 2
              name="$2"
              if [[ "$name" =~ ^Recording-[0-9]{8}-[0-9]{6}-[0-9]+\.mp4$ ]]; then
                path="$recordings/$name"
                kind=recording
              elif [[ "$name" =~ ^Screenshot-[0-9]{8}-[0-9]{6}-[0-9]+\.png$ ]]; then
                path="''${XDG_PICTURES_DIR:-$HOME/Pictures}/Screenshots/$name"
                kind=image
              else
                exit 2
              fi
              [ -f "$path" ] && [ ! -L "$path" ] || exit 2
              if [ "$action" = open ]; then
                exec xdg-open "$path"
              elif [ "$action" = edit ]; then
                if [ "$kind" = image ]; then exec ${lib.getExe imageMarkup} "$path"; fi
                exec losslesscut --disable-networking "$path"
              elif [ "$action" = copy ]; then
                [ "$kind" = image ] || exit 2
                exec wl-copy --type image/png < "$path"
              elif [ "$action" = trash ]; then
                exec gio trash "$path"
              fi
              if [ "$kind" = image ]; then
                printf '%s\n' "$path"
                exit 0
              fi
              [ ! -L "$preview_dir" ] || exit 2
              umask 077
              mkdir -p -- "$preview_dir"
              chmod 700 -- "$preview_dir"
              find "$preview_dir" -maxdepth 1 -type f -name 'recording-*.png' -delete
              output="$(mktemp "$preview_dir/recording-XXXXXXXX.png")"
              trap 'rm -f -- "$output"' EXIT
              ffmpeg -hide_banner -loglevel error -ss 0.2 -i "$path" \
                -vf 'scale=510:300:force_original_aspect_ratio=decrease' \
                -frames:v 1 -y "$output" >/dev/null
              printf '%s\n' "$output"
              trap - EXIT
              ;;
            *) exit 2 ;;
          esac
        '';
      };

      recordingFinalize = pkgs.writeShellApplication {
        name = "linux-desktop-recording-finalize";
        runtimeInputs = [
          pkgs.coreutils
          pkgs.ffmpeg
          pkgs.libnotify
        ];
        text = ''
          state="''${XDG_RUNTIME_DIR:?}/linux-desktop-recording.state"
          [ -r "$state" ] || exit 0
          { IFS= read -r previous && IFS= read -r started && IFS= read -r savedPath; } < "$state" || exit 0
          [[ "$savedPath" == /*/Recording-*.mp4 ]] || exit 0
          case "$previous" in recording|finalising) ;; *) exit 0 ;; esac
          if [ -s "$savedPath" ] && ffprobe -v error -select_streams v:0 -show_entries stream=codec_type -of csv=p=0 "$savedPath" | grep -qx video; then
            printf 'completed\n%s\n%s\n' "$started" "$savedPath" > "$state"
            notify-send --app-name=linux-desktop "Recording saved" "$(basename "$savedPath")" || true
          else
            printf 'failed\n%s\n%s\n' "$started" "$savedPath" > "$state"
            notify-send --app-name=linux-desktop -u critical "Recording failed" "Could not finalise the selected capture" || true
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
              exec hyprctl dispatch "hl.dsp.exit()"
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
        themeSet
        windowEffectsToggle
        launcher
        paletteSearch
        developmentLauncher
        lockCommand
        sessionCommand
        clipboardCopy
        videoWallpaper
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
        Path.PathChanged = "%h/.config/linux-desktop/runtime.json";
        Install.WantedBy = [ "hyprland-session.target" ];
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
            PartOf = [ "hyprland-session.target" ];
          };
          Service = {
            Type = "simple";
            ExecStart = "${lib.getExe paletteSearch} watch";
            Restart = "on-failure";
            RestartSec = "5s";
          };
          Install.WantedBy = [ "hyprland-session.target" ];
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

        linux-desktop-night-light = {
          Unit = {
            Description = "Manual Hyprland colour temperature";
            After = [ "hyprland-session.target" ];
            PartOf = [ "hyprland-session.target" ];
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
            After = [ "hyprland-session.target" ];
          };
          Service = {
            Type = "oneshot";
            ExecStart = "${lib.getExe nightLightControl} apply";
          };
          Install.WantedBy = [ "hyprland-session.target" ];
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
            ExecStopPost = lib.getExe recordingFinalize;
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
            # Home Manager atomically replaces runtime.json's symlink on theme
            # switches. Restart on the evaluated config change: FileView watches
            # the former symlink target, not the replacement inode.
            X-Restart-Triggers = [ runtimeConfig ];
            PartOf = [ "hyprland-session.target" ];
            Wants = [ "linux-desktop-spectrum.service" ];
            After = [
              "hyprland-session.target"
              "linux-desktop-spectrum.service"
            ];
          };

          Service = {
            ExecStartPre = "${lib.getExe' pkgs.coreutils "touch"} %t/linux-desktop-recording.state";
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
