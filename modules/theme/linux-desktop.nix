{
  configurationFlakeSubdirectory ? null,
  configurationName,
  configurationOutputName,
  lib,
  pkgs,
  primaryUser,
  repoPath,
}:

let
  themeRegistry = import ./registry.nix { inherit lib pkgs; };
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
      repoPath=${lib.escapeShellArg repoPath}
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

in
{
  inherit themeSet;

  palette =
    config:
    let
      colors = config.lib.stylix.colors.withHashtag;
    in
    {
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

  monoFont = config: config.stylix.fonts.monospace.name;
}
