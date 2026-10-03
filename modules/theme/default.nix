{
  config,
  configurationName,
  lib,
  pkgs,
  repoSource,
  scopeConfig,
  themeVariant ? null,
  ...
}:

let
  themeRegistry = import ./registry.nix { inherit lib pkgs; };
  activeThemeName = if themeVariant == null then themeRegistry.default else themeVariant;
  activeTheme = themeRegistry.resolve activeThemeName;
  activeAssets = activeTheme.assets;
  primaryUser = config.dotfiles.users.primary.name;
  inherit (scopeConfig) runtimeSwitching;
  isSpecialisation = config.isSpecialisation or false;
  prepareRuntimeVariants = runtimeSwitching && themeVariant == null && !isSpecialisation;
  themeNames = builtins.attrNames themeRegistry.variants;
  validThemePattern = lib.concatStringsSep "|" themeNames;
  themeRootDir = "/nix/var/nix/gcroots/dotfiles-themes";
  themeStateDir = "/var/lib/dotfiles-theme-variants";
  themeSource = toString repoSource;
  themeSourceId = builtins.baseNameOf themeSource;

  themeManifest = pkgs.writeText "dotfiles-theme-registry.json" (
    builtins.toJSON {
      inherit (themeRegistry) default;
      themes = lib.mapAttrsToList (
        name: _:
        let
          theme = themeRegistry.resolve name;
        in
        {
          inherit name;
          inherit (theme) label polarity;
        }
      ) themeRegistry.variants;
    }
  );

  themePrepareSystem = pkgs.writeShellApplication {
    name = "dotfiles-theme-prepare-system";
    runtimeInputs = [
      pkgs.coreutils
      config.nix.package
    ]
    ++ lib.optionals pkgs.stdenv.hostPlatform.isLinux [ pkgs.util-linux ];
    text = ''
            if [ "$(id -u)" -ne 0 ]; then
              echo "dotfiles-theme-prepare-system must run as root" >&2
              exit 1
            fi

            selected="''${1:-all}"
            case "$selected" in
              all|${validThemePattern}) ;;
              *)
                echo "Unknown theme: $selected" >&2
                exit 2
                ;;
            esac

            rootDir=${lib.escapeShellArg themeRootDir}
            stateDir=${lib.escapeShellArg themeStateDir}
            source=${lib.escapeShellArg themeSource}
            sourceId=${lib.escapeShellArg themeSourceId}
            configurationName=${lib.escapeShellArg configurationName}
            configurationSet=${
              lib.escapeShellArg (
                if pkgs.stdenv.hostPlatform.isDarwin then "darwinConfigurations" else "nixosConfigurations"
              )
            }

            install -d -m 0755 "$rootDir" "$stateDir"

            prepare_theme() {
              selected="$1"
              root="$rootDir/$selected"
              marker="$stateDir/$selected.source"

              ${lib.optionalString pkgs.stdenv.hostPlatform.isLinux ''
                lock="/run/lock/dotfiles-theme-$selected.lock"
                exec 9>"$lock"
                flock 9
              ''}

              if [ -L "$root" ] && [ -f "$marker" ] && [ "$(cat "$marker")" = "$sourceId" ]; then
                return
              fi

              if [ "$configurationSet" = nixosConfigurations ]; then
                expression="$(
                  cat <<EOF
      let
        f = builtins.getFlake "path:$source";
        base = builtins.getAttr "$configurationName" f.nixosConfigurations;
        themed = base.extendModules {
          specialArgs.themeVariant = "$selected";
          modules = [
            {
              specialisation."$selected".configuration = { };
            }
          ];
        };
      in
        themed.config.specialisation."$selected".configuration.system.build.toplevel
      EOF
                )"
              else
                expression="$(
                  cat <<EOF
      let
        f = builtins.getFlake "path:$source";
        base = builtins.getAttr "$configurationName" f.darwinConfigurations;
        themed = base.extendModules {
          specialArgs.themeVariant = "$selected";
        };
      in
        themed.config.system.build.toplevel
      EOF
                )"
              fi

              nix build --impure --out-link "$root" --expr "$expression"

              tmpMarker="$marker.tmp.$$"
              printf '%s\n' "$sourceId" > "$tmpMarker"
              mv -f "$tmpMarker" "$marker"
            }

            if [ "$selected" = all ]; then
              for selected in ${lib.escapeShellArgs themeNames}; do
                prepare_theme "$selected"
              done
            else
              prepare_theme "$selected"
            fi
    '';
  };

  themeActivateSystem = pkgs.writeShellApplication {
    name = "dotfiles-theme-activate-system";
    runtimeInputs = [ pkgs.coreutils ];
    text = ''
      if [ "$(id -u)" -ne 0 ]; then
        echo "dotfiles-theme-activate-system must run as root" >&2
        exit 1
      fi

      selected="''${1:-}"
      case "$selected" in
        ${validThemePattern}) ;;
        *)
          echo "Unknown theme: $selected" >&2
          exit 2
          ;;
      esac

      root=${lib.escapeShellArg themeRootDir}/$selected
      marker=${lib.escapeShellArg themeStateDir}/$selected.source
      sourceId=${lib.escapeShellArg themeSourceId}

      if [ ! -L "$root" ] || [ ! -f "$marker" ] || [ "$(cat "$marker")" != "$sourceId" ]; then
        ${lib.getExe themePrepareSystem} "$selected"
      fi

      system="$(readlink -f "$root")"
      if [ ! -d "$system" ]; then
        echo "Theme variant is not registered: $selected" >&2
        exit 3
      fi

      ${
        if pkgs.stdenv.hostPlatform.isDarwin then
          ''
            exec "$system/activate"
          ''
        else
          ''
            exec "$system/bin/switch-to-configuration" test
          ''
      }
    '';
  };

  themeActivatorExe = lib.getExe themeActivateSystem;
  themeSudoCommands = lib.concatMapStringsSep ", " (name: "${themeActivatorExe} ${name}") (
    builtins.attrNames themeRegistry.variants
  );

  themeSet = pkgs.writeShellApplication {
    name = "theme-set";
    runtimeInputs = [ pkgs.coreutils ];
    text = ''
      defaultTheme=${lib.escapeShellArg themeRegistry.default}
      expectedUser=${lib.escapeShellArg primaryUser}
      manifest=${lib.escapeShellArg (toString themeManifest)}
      stateDir="''${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles"
      stateFile="$stateDir/theme"

      valid_theme() {
        case "$1" in
          ${validThemePattern}) return 0 ;;
          *) return 1 ;;
        esac
      }

      desired_theme() {
        if [ -s "$stateFile" ]; then
          selected="$(cat "$stateFile")"
          if valid_theme "$selected"; then
            printf '%s\n' "$selected"
            return
          fi
        fi
        printf '%s\n' "$defaultTheme"
      }

      current_theme() {
        currentSystem="$(readlink -f /run/current-system 2>/dev/null || true)"
        for selected in ${lib.escapeShellArgs (builtins.attrNames themeRegistry.variants)}; do
          root="/nix/var/nix/gcroots/dotfiles-themes/$selected"
          if [ -L "$root" ] && [ "$currentSystem" = "$(readlink -f "$root")" ]; then
            printf '%s\n' "$selected"
            return
          fi
        done
        printf '%s\n' "$defaultTheme"
      }

      apply_theme() {
        selected="$1"
        if [ "''${USER:-}" != "$expectedUser" ]; then
          printf 'theme-set is configured for user %s, not %s\n' "$expectedUser" "''${USER:-unknown}" >&2
          exit 1
        fi
        if ! valid_theme "$selected"; then
          printf 'Unknown theme: %s\n' "$selected" >&2
          exit 2
        fi

        sudo -n ${themeActivatorExe} "$selected"

        umask 077
        install -d -m 0700 "$stateDir"
        tmp="$(mktemp "$stateDir/theme.XXXXXX")"
        printf '%s\n' "$selected" > "$tmp"
        mv "$tmp" "$stateFile"
        printf '%s\n' "$selected"
      }

      case "''${1:-}" in
        list)
          if [ "''${2:-}" = "--json" ]; then cat "$manifest"; else
            ${lib.concatMapStringsSep "\n" (name: "printf '%s\n' ${lib.escapeShellArg name}") (
              builtins.attrNames themeRegistry.variants
            )}
          fi
          ;;
        current) current_theme ;;
        restore)
          selected="$(desired_theme)"
          if [ "$selected" != "$(current_theme)" ]; then apply_theme "$selected" >/dev/null; fi
          ;;
        "")
          echo 'Usage: theme-set [list [--json]|current|restore|<theme>]' >&2
          exit 2
          ;;
        *) apply_theme "$1" ;;
      esac
    '';
  };

in
{
  scopeOptions.runtimeSwitching = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = "Prepare complete host theme specialisations lazily for runtime switching.";
  };

  stylix = {
    enable = true;
    image = activeAssets.wallpaper;

    inherit (activeTheme) fonts polarity;
    inherit (activeAssets) cursor;
  }
  // lib.optionalAttrs (activeTheme ? colors) {
    base16Scheme = {
      system = "base16";
      name = activeTheme.label;
      variant = activeTheme.polarity;
      palette = activeTheme.colors;
    };
  };

  environment.systemPackages = lib.optionals runtimeSwitching [
    themeSet
    themeActivateSystem
    themePrepareSystem
  ];

  security.sudo.extraConfig = lib.mkIf runtimeSwitching (
    lib.mkAfter ''
      ${primaryUser} ALL=(root) NOPASSWD: ${themeSudoCommands}
    ''
  );

  system.activationScripts =
    if pkgs.stdenv.hostPlatform.isDarwin then
      { }
    else
      {
        dotfilesThemeVariants = lib.mkIf prepareRuntimeVariants {
          text = ''
            ${pkgs.systemd}/bin/systemd-run \
              --quiet \
              --collect \
              --unit=dotfiles-theme-variants-${themeSourceId} \
              --property=Nice=10 \
              --property=IOSchedulingClass=idle \
              --property=MemoryHigh=25% \
              ${lib.getExe themePrepareSystem} all || true
          '';
        };
      };

  fonts =
    { lib, pkgs, ... }:
    let
      nerdSymbols =
        if builtins.hasAttr "nerd-fonts" pkgs then
          pkgs."nerd-fonts".symbols-only
        else
          pkgs.nerdfonts.override { fonts = [ "NerdFontsSymbolsOnly" ]; };
    in
    {
      # Stylix already installs its configured fonts and sets the standard
      # fontconfig defaults. Keep only the additional symbol fallback here.
      fonts.packages = [ nerdSymbols ];
      fonts.fontconfig.defaultFonts.monospace = lib.mkAfter [
        "Symbols Nerd Font Mono"
        "Symbols Nerd Font"
      ];
    };

  home =
    {
      config,
      lib,
      osConfig,
      pkgs,
      ...
    }:

    let
      toml = pkgs.formats.toml { };
      yaml = pkgs.formats.yaml { };
      tuicrEnabled = osConfig.dotfiles.resolvedScopes.cli.git.tuicr.enable;
      syntaxScope = name: selectors: color: ''
        <dict>
          <key>name</key><string>${name}</string>
          <key>scope</key><string>${selectors}</string>
          <key>settings</key><dict><key>foreground</key><string>${color}</string></dict>
        </dict>
      '';
      syntaxTheme =
        with config.lib.stylix.colors.withHashtag;
        pkgs.writeText "stylix.tmTheme" ''
          <?xml version="1.0" encoding="UTF-8"?>
          <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
          <plist version="1.0">
            <dict>
              <key>name</key>
              <string>Stylix</string>
              <key>settings</key>
              <array>
                <dict>
                  <key>settings</key>
                  <dict>
                    <key>background</key><string>${base00}</string>
                    <key>caret</key><string>${base05}</string>
                    <key>foreground</key><string>${base05}</string>
                    <key>invisibles</key><string>${base03}</string>
                    <key>lineHighlight</key><string>${base01}</string>
                    <key>selection</key><string>${base02}</string>
                  </dict>
                </dict>
                ${syntaxScope "Comments" "comment, punctuation.definition.comment" base03}
                ${syntaxScope "Identifiers" "variable, variable.parameter, variable.other.readwrite" base05}
                ${syntaxScope "Properties and attribute names"
                  "entity.other.attribute-name, variable.other.property, variable.other.constant.property"
                  base0C
                }
                ${syntaxScope "Tags and markup" "entity.name.tag, markup.list, markup.link.text" base08}
                ${syntaxScope "Constants"
                  "constant.numeric, constant.language, constant.character, variable.other.constant"
                  base09
                }
                ${syntaxScope "Types and classes"
                  "entity.name.type, entity.name.class, support.class, storage.type"
                  base0A
                }
                ${syntaxScope "Strings" "string, markup.inline.raw, markup.fenced_code" base0B}
                ${syntaxScope "Support, regular expressions, and escapes"
                  "support, string.regexp, constant.character.escape"
                  base0C
                }
                ${syntaxScope "Functions and headings"
                  "entity.name.function, support.function, markup.heading, entity.name.section"
                  base0D
                }
                ${syntaxScope "Keywords and storage" "keyword, storage" base0E}
                ${syntaxScope "Deprecated" "invalid.deprecated, deprecated" base0F}
                ${syntaxScope "Invalid" "invalid.illegal" base08}
                ${syntaxScope "Namespaces" "entity.name.namespace" base04}
                ${syntaxScope "Punctuation and operators" "punctuation, keyword.operator" base04}
              </array>
            </dict>
          </plist>
        '';
    in
    {
      # Shared Home Manager theme defaults moved here so all theme policy lives
      # in one module.
      stylix.targets.qt.platform = "kde";
      stylix.targets.vscode.enable = false;
      stylix.targets.bat.enable = false;

      programs.bat = {
        config.theme = "stylix";
        themes.stylix.src = syntaxTheme;
      };

      home.sessionVariables = lib.mkIf config.programs.bat.enable {
        MANPAGER = "${lib.getExe config.programs.bat.package} -plman";
      };

      programs.delta.options = with config.lib.stylix.colors.withHashtag; {
        minus-style = "syntax ${base01}";
        minus-emph-style = "${base08} ${base02} bold";
        plus-style = "syntax ${base01}";
        plus-emph-style = "${base0B} ${base02} bold";
        syntax-theme = "stylix";
        line-numbers-minus-style = base08;
        line-numbers-plus-style = base0B;
        line-numbers-zero-style = base03;
        file-style = base0D;
        hunk-header-style = base0D;
        word-diff-regex = ".";
      };

      xdg.configFile = {
        "bat/themes/stylix.tmTheme" =
          lib.mkIf (!config.programs.bat.enable && config.programs.delta.enable)
            {
              source = syntaxTheme;
            };

        "tuicr/themes/stylix.tmTheme" = lib.mkIf tuicrEnabled {
          source = syntaxTheme;
        };

        "tuicr/themes/stylix.toml" = lib.mkIf tuicrEnabled {
          source = toml.generate "tuicr-stylix-theme.toml" (
            with config.lib.stylix.colors.withHashtag;
            {
              panel_bg = base00;
              bg_highlight = base02;
              fg_primary = base05;
              fg_secondary = base04;
              fg_dim = base03;
              diff_add = base0B;
              diff_add_bg = base01;
              diff_del = base08;
              diff_del_bg = base01;
              diff_context = base05;
              diff_hunk_header = base0D;
              expanded_context_fg = base04;
              syntax_add_bg = base01;
              syntax_del_bg = base01;
              syntax_theme = "stylix.tmTheme";
              file_added = base0B;
              file_modified = base0D;
              file_deleted = base08;
              file_renamed = base0A;
              reviewed = base0B;
              pending = base09;
              comment_note = base0D;
              comment_suggestion = base0C;
              comment_issue = base08;
              comment_praise = base0B;
              border_focused = base0D;
              border_unfocused = base03;
              status_bar_bg = base01;
              cursor_color = base0A;
              cursor_line_bg = base02;
              branch_name = base0E;
              help_indicator = base04;
              message_info_fg = base00;
              message_info_bg = base0D;
              message_warning_fg = base00;
              message_warning_bg = base09;
              message_error_fg = base00;
              message_error_bg = base08;
              update_badge_fg = base00;
              update_badge_bg = base09;
              mode_fg = base00;
              mode_bg = base0D;
            }
          );
        };

        "gh-dash/stylix.yml" = lib.mkIf config.programs.gh.enable {
          source = yaml.generate "gh-dash-stylix.yml" (
            with config.lib.stylix.colors.withHashtag;
            {
              theme.colors = {
                text = {
                  primary = base05;
                  secondary = base04;
                  inverted = base00;
                  faint = base03;
                  warning = base09;
                  success = base0B;
                  error = base08;
                  actor = base0D;
                };
                background.selected = base02;
                border = {
                  primary = base0D;
                  secondary = base04;
                  faint = base01;
                };
                icon = {
                  newcontributor = base0B;
                  contributor = base0D;
                  collaborator = base0A;
                  member = base0A;
                  owner = base09;
                  unknownrole = base04;
                };
              };
            }
          );
        };
      };

      home.activation.deltaSyntaxThemeCache =
        lib.mkIf (config.programs.delta.enable && !config.programs.bat.enable)
          (
            lib.hm.dag.entryAfter [ "linkGeneration" ] ''
              (
                export XDG_CACHE_HOME=${lib.escapeShellArg config.xdg.cacheHome}
                verboseEcho "Rebuilding delta syntax theme cache"
                cd "${pkgs.emptyDirectory}"
                run ${lib.getExe pkgs.bat} cache --build
              )
            ''
          );

      gtk = lib.mkIf pkgs.stdenv.hostPlatform.isLinux {
        gtk4.theme = lib.mkDefault config.gtk.theme;

        iconTheme = activeAssets.icons;
      };
    };

  cava = _: {
    home =
      {
        config,
        lib,
        osConfig,
        ...
      }:
      {
        config = lib.mkIf osConfig.dotfiles.resolvedScopes.cli.cava.enable {
          programs.cava.settings.color = {
            gradient = 1;
            gradient_count = 8;
            gradient_color_1 = "'#${config.lib.stylix.colors.base01}'";
            gradient_color_2 = "'#${config.lib.stylix.colors.base02}'";
            gradient_color_3 = "'#${config.lib.stylix.colors.base03}'";
            gradient_color_4 = "'#${config.lib.stylix.colors.base04}'";
            gradient_color_5 = "'#${config.lib.stylix.colors.base05}'";
            gradient_color_6 = "'#${config.lib.stylix.colors.base06}'";
            gradient_color_7 = "'#${config.lib.stylix.colors.base07}'";
            gradient_color_8 = "'#${config.lib.stylix.colors.base08}'";
          };
        };
      };
  };

}
