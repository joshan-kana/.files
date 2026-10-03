{
  config,
  lib,
  pkgs,
  themeRegistry,
}:

let
  themes = lib.mapAttrs (name: _: themeRegistry.resolve name) themeRegistry.variants;

  fontPackages = lib.unique (
    lib.concatMap (
      theme: with theme.fonts; [
        serif.package
        sansSerif.package
        monospace.package
        emoji.package
      ]
    ) (builtins.attrValues themes)
  );

  assetPackages = lib.unique (
    lib.concatMap (
      theme: with theme.assets; [
        cursor.package
        icons.package
      ]
    ) (builtins.attrValues themes)
  );

  paletteJsonFor =
    name: theme:
    if theme ? colors then
      pkgs.writeText "dotfiles-theme-${name}-palette.json" (builtins.toJSON theme.colors)
    else
      pkgs.runCommand "dotfiles-theme-${name}-palette.json"
        {
          nativeBuildInputs = [ config.stylix.paletteGenerator ];
          inherit (theme) polarity;
          wallpaper = theme.assets.wallpaper;
        }
        ''
          palette-generator "$polarity" "$wallpaper" "$out"
        '';

  themePacks = lib.mapAttrs (
    name: theme:
    let
      paletteJson = paletteJsonFor name theme;
    in
    pkgs.runCommand "dotfiles-theme-pack-${name}"
      {
        nativeBuildInputs = [ pkgs.jq ];

        inherit paletteJson;
        themeName = name;
        themeLabel = theme.label;
        inherit (theme) polarity;

        wallpaper = theme.assets.wallpaper;
        cursorPackage = theme.assets.cursor.package;
        cursorName = theme.assets.cursor.name;
        cursorSize = toString theme.assets.cursor.size;
        iconsPackage = theme.assets.icons.package;
        iconsName = theme.assets.icons.name;

        serifFontPackage = theme.fonts.serif.package;
        serifFontName = theme.fonts.serif.name;
        sansFontPackage = theme.fonts.sansSerif.package;
        sansFontName = theme.fonts.sansSerif.name;
        monospaceFontPackage = theme.fonts.monospace.package;
        monospaceFontName = theme.fonts.monospace.name;
        emojiFontPackage = theme.fonts.emoji.package;
        emojiFontName = theme.fonts.emoji.name;
      }
      ''
        mkdir -p "$out"
        ln -s "$wallpaper" "$out/wallpaper"

        colors="$(
          jq '{
            base00, base01, base02, base03,
            base04, base05, base06, base07,
            base08, base09, base0A, base0B,
            base0C, base0D, base0E, base0F
          } | with_entries(.value |= ltrimstr("#"))' "$paletteJson"
        )"

        jq -n \
          --arg name "$themeName" \
          --arg label "$themeLabel" \
          --arg polarity "$polarity" \
          --arg wallpaper "$wallpaper" \
          --arg cursorPackage "$cursorPackage" \
          --arg cursorName "$cursorName" \
          --argjson cursorSize "$cursorSize" \
          --arg iconsPackage "$iconsPackage" \
          --arg iconsName "$iconsName" \
          --arg serifFontPackage "$serifFontPackage" \
          --arg serifFontName "$serifFontName" \
          --arg sansFontPackage "$sansFontPackage" \
          --arg sansFontName "$sansFontName" \
          --arg monospaceFontPackage "$monospaceFontPackage" \
          --arg monospaceFontName "$monospaceFontName" \
          --arg emojiFontPackage "$emojiFontPackage" \
          --arg emojiFontName "$emojiFontName" \
          --argjson colors "$colors" \
          '{
            name: $name,
            label: $label,
            polarity: $polarity,
            colors: $colors,
            wallpaper: $wallpaper,
            cursor: {
              package: $cursorPackage,
              name: $cursorName,
              size: $cursorSize
            },
            icons: {
              package: $iconsPackage,
              name: $iconsName
            },
            fonts: {
              serif: {
                package: $serifFontPackage,
                name: $serifFontName
              },
              sansSerif: {
                package: $sansFontPackage,
                name: $sansFontName
              },
              monospace: {
                package: $monospaceFontPackage,
                name: $monospaceFontName
              },
              emoji: {
                package: $emojiFontPackage,
                name: $emojiFontName
              }
            }
          }' > "$out/theme.json"


      ''
  ) themes;

  manifest = pkgs.writeText "dotfiles-runtime-themes.json" (
    builtins.toJSON {
      inherit (themeRegistry) default;
      themes = lib.mapAttrsToList (name: theme: {
        inherit name;
        inherit (theme) label polarity;
        pack = toString themePacks.${name};
      }) themes;
    }
  );

  themeSet = pkgs.writeShellApplication {
    name = "theme-set";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.jq
    ];
    text = ''
      defaultTheme=${lib.escapeShellArg themeRegistry.default}
      manifest=${lib.escapeShellArg (toString manifest)}
      stateDir="''${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles/theme"
      hooksDir="''${XDG_CONFIG_HOME:-$HOME/.config}/dotfiles/theme-hooks"

      valid_theme() {
        jq -e --arg selected "$1" \
          '.themes[] | select(.name == $selected)' \
          "$manifest" >/dev/null
      }

      pack_for() {
        jq -r --arg selected "$1" \
          '.themes[] | select(.name == $selected) | .pack' \
          "$manifest"
      }

      selected_theme() {
        if [ -s "$stateDir/selected" ]; then
          selected="$(cat "$stateDir/selected")"
          if valid_theme "$selected"; then
            printf '%s\n' "$selected"
            return
          fi
        fi

        printf '%s\n' "$defaultTheme"
      }

      current_theme() {
        if [ -r "$stateDir/current/theme.json" ]; then
          selected="$(jq -r '.name' "$stateDir/current/theme.json")"
          if valid_theme "$selected"; then
            printf '%s\n' "$selected"
            return
          fi
        fi

        selected_theme
      }

      publish_link() {
        target="$1"
        path="$2"
        tmp="$path.tmp.$$"

        rm -f "$tmp"
        ln -s "$target" "$tmp"
        mv -Tf "$tmp" "$path"
      }

      run_hooks() {
        pack="$1"
        selected="$2"

        [ -d "$hooksDir" ] || return 0

        for hook in "$hooksDir"/*; do
          [ -x "$hook" ] || continue
          if ! "$hook" "$pack" "$selected"; then
            printf 'Theme hook failed: %s\n' "$hook" >&2
          fi
        done
      }

      apply_theme() {
        selected="$1"

        if ! valid_theme "$selected"; then
          printf 'Unknown theme: %s\n' "$selected" >&2
          exit 2
        fi

        pack="$(pack_for "$selected")"

        umask 077
        install -d -m 0700 "$stateDir"
        publish_link "$pack" "$stateDir/current"

        tmp="$stateDir/selected.tmp.$$"
        printf '%s\n' "$selected" > "$tmp"
        mv -f "$tmp" "$stateDir/selected"

        run_hooks "$pack" "$selected"
        printf '%s\n' "$selected"
      }

      case "''${1:-}" in
        list)
          if [ "''${2:-}" = "--json" ]; then
            cat "$manifest"
          else
            jq -r '.themes[].name' "$manifest"
          fi
          ;;
        current)
          current_theme
          ;;
        restore)
          apply_theme "$(selected_theme)" >/dev/null
          ;;
        "")
          echo 'Usage: theme-set [list [--json]|current|restore|<theme>]' >&2
          exit 2
          ;;
        *)
          apply_theme "$1"
          ;;
      esac
    '';
  };
in
{
  inherit
    assetPackages
    fontPackages
    manifest
    themePacks
    themeSet
    ;
}
