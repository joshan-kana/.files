{
  inputs,
  lib,
  pkgs,
  scopeConfig,
  system,
  ...
}:

let
  themeRegistry = import ./registry.nix { inherit lib pkgs; };
  activeTheme = themeRegistry.resolve scopeConfig.name;
  activeAssets = activeTheme.assets;
  inherit (lib.systems.elaborate system) isDarwin isLinux;
  browserFontPolicy."browser.display.use_document_fonts" = {
    Value = 0;
    Status = "default";
    Type = "number";
  };
  syntaxTheme =
    { config, pkgs }:
    let
      syntaxScope = name: selectors: color: ''
        <dict>
          <key>name</key><string>${name}</string>
          <key>scope</key><string>${selectors}</string>
          <key>settings</key><dict><key>foreground</key><string>${color}</string></dict>
        </dict>
      '';
    in
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
  bootSplash =
    { config, pkgs, ... }:
    let
      frames = 60;
      resolution = 768;
      background =
        with config.lib.stylix.colors;
        "${toString base00-dec-r}, ${toString base00-dec-g}, ${toString base00-dec-b}";
      foreground =
        with config.lib.stylix.colors;
        "${toString base05-dec-r}, ${toString base05-dec-g}, ${toString base05-dec-b}";
      renderFrames = pkgs.writeText "plymouth-wireframe.py" ''
        import math
        import pathlib
        import subprocess
        import sys
        import tempfile

        destination = pathlib.Path(sys.argv[1])
        foreground, secondary = ("#" + color for color in sys.argv[2:4])
        count = int(sys.argv[4])
        size = int(sys.argv[5])
        radius = size * 0.36
        center = size / 2
        circle = 2 * math.pi
        golden_angle = math.pi * (3 - math.sqrt(5))

        def rotate(point, yaw, pitch):
            x, y, z = point
            x, z = x * math.cos(yaw) + z * math.sin(yaw), -x * math.sin(yaw) + z * math.cos(yaw)
            y, z = y * math.cos(pitch) - z * math.sin(pitch), y * math.sin(pitch) + z * math.cos(pitch)
            return x, y, z

        def paths(points):
            sections = []
            section = []
            current_depth = None
            for previous, following in zip(points, points[1:]):
                depth = (previous[2] + following[2]) >= 0
                if depth != current_depth:
                    if section:
                        sections.append((current_depth, section))
                    section = [f"M {previous[0]:.2f} {previous[1]:.2f}"]
                    current_depth = depth
                section.append(f"L {following[0]:.2f} {following[1]:.2f}")
            if section:
                sections.append((current_depth, section))
            return sections

        with tempfile.TemporaryDirectory() as temporary:
            svg = pathlib.Path(temporary) / "frame.svg"
            for frame in range(count):
                turn = circle * frame / count
                pitch = 0.26 + 0.18 * math.sin(turn)
                art = [f'<svg xmlns="http://www.w3.org/2000/svg" width="{size}" height="{size}" viewBox="0 0 {size} {size}">']
                for index in range(38):
                    tilt = 0.10 + 1.35 * index / 37
                    node = (index * golden_angle) % circle
                    points = []
                    for sample in range(193):
                        angle = circle * sample / 192
                        radial = 1 - 0.025 * math.sin(3 * angle + index * 0.7)
                        x = radial * math.cos(angle)
                        y = radial * math.sin(angle) * math.cos(tilt)
                        z = radial * math.sin(angle) * math.sin(tilt)
                        x, y = x * math.cos(node) - y * math.sin(node), x * math.sin(node) + y * math.cos(node)
                        x, y, z = rotate((x, y, z), turn, pitch)
                        points.append((center + radius * x, center + radius * y, z))
                    for front, section in paths(points):
                        path = " ".join(section)
                        # Faint halos soften the strokes without raster blur.
                        art.append(f'<path d="{path}" fill="none" stroke="{secondary}" stroke-width="2.4" stroke-opacity="0.04"/>')
                        art.append(f'<path d="{path}" fill="none" stroke="{foreground}" stroke-width="0.75" stroke-opacity="{0.65 if front else 0.20}"/>')
                art.append('</svg>')
                svg.write_text("\n".join(art))
                image = destination / f"frame-{frame}.png"
                subprocess.run(["rsvg-convert", "--format=png", "--output", str(image), str(svg)], check=True)
                indexed = destination / f"frame-{frame}.indexed.png"
                result = subprocess.run([
                    "pngquant", "--quality=90-100", "--speed=3", "--output", str(indexed), str(image)
                ], check=False)
                if result.returncode == 0:
                    indexed.replace(image)
                elif result.returncode != 99:
                    raise RuntimeError(f"pngquant failed: {result.returncode}")
      '';
      theme =
        pkgs.runCommand "stylix-wireframe-plymouth"
          {
            nativeBuildInputs = [
              pkgs.python3
              pkgs.librsvg
              pkgs.pngquant
            ];
          }
          ''
            themeDir="$out/share/plymouth/themes/wireframe"
            mkdir -p "$themeDir"
            python3 ${renderFrames} "$themeDir" \
              "${config.lib.stylix.colors.base05}" "${config.lib.stylix.colors.base04}" \
              ${toString frames} ${toString resolution}
            cat > "$themeDir/wireframe.plymouth" <<EOF
            [Plymouth Theme]
            Name=Wireframe
            ModuleName=script

            [script]
            ImageDir=$themeDir
            ScriptFile=$themeDir/wireframe.script
            EOF
            cat > "$themeDir/wireframe.script" <<'EOF'
            center_x = Window.GetWidth() / 2;
            center_y = Window.GetHeight() / 2;
            bottom_y = Window.GetHeight() * 0.85;
            message_y = Window.GetHeight() * 0.74;
            Window.SetBackgroundTopColor(${background});
            Window.SetBackgroundBottomColor(${background});

            width = Math.Min(${toString resolution}, Math.Min(Window.GetWidth(), Window.GetHeight()) * 0.52);
            images = [];
            for (i = 0; i < ${toString frames}; i++) {
              image = Image("frame-" + i + ".png");
              images[i] = image.Scale(width, width);
            }
            orb = Sprite(images[0]);
            orb.SetPosition(center_x - width / 2, center_y - width / 2, 1);
            tick = 0;
            fun animate() {
              orb.SetImage(images[Math.Int(tick / 2) % ${toString frames}]);
              tick++;
            }
            Plymouth.SetRefreshFunction(animate);

            prompt = null;
            bullets = null;
            bullet = Image.Text("•", ${foreground});
            fun password_callback(label, count) {
              prompt = null;
              bullets = null;
              prompt_image = Image.Text(label, ${foreground});
              prompt = Sprite(prompt_image);
              prompt.SetPosition(center_x - prompt_image.GetWidth() / 2, bottom_y - prompt_image.GetHeight(), 2);
              start_x = center_x - count * bullet.GetWidth() / 2;
              for (i = 0; i < count; i++) {
                bullets[i] = Sprite(bullet);
                bullets[i].SetPosition(start_x + i * bullet.GetWidth(), bottom_y + bullet.GetHeight(), 2);
              }
            }
            Plymouth.SetDisplayPasswordFunction(password_callback);

            question = null;
            answer = null;
            fun question_callback(label, entry) {
              question = null;
              answer = null;
              question_image = Image.Text(label, ${foreground});
              answer_image = Image.Text(entry, ${foreground});
              question = Sprite(question_image);
              answer = Sprite(answer_image);
              question.SetPosition(center_x - question_image.GetWidth() / 2, bottom_y - question_image.GetHeight(), 2);
              answer.SetPosition(center_x - answer_image.GetWidth() / 2, bottom_y + answer_image.GetHeight(), 2);
            }
            Plymouth.SetDisplayQuestionFunction(question_callback);

            message = null;
            fun message_callback(text) {
              message = null;
              message_image = Image.Text(text, ${foreground});
              message = Sprite(message_image);
              message.SetPosition(center_x - message_image.GetWidth() / 2, message_y, 2);
            }
            Plymouth.SetMessageFunction(message_callback);

            fun normal_callback() {
              prompt = null;
              bullets = null;
              question = null;
              answer = null;
              message = null;
            }
            Plymouth.SetDisplayNormalFunction(normal_callback);
            Plymouth.SetQuitFunction(normal_callback);
            EOF
          '';
    in
    lib.optionalAttrs isLinux {
      stylix.targets.plymouth.enable = false;
      boot.plymouth = {
        theme = "wireframe";
        themePackages = [ theme ];
        showDelay = 0;
      };
      boot.kernelParams = lib.optionals config.boot.plymouth.enable [ "quiet" ];
    };

  scopeOptions.name = lib.mkOption {
    type = lib.types.enum (builtins.attrNames themeRegistry.variants);
    inherit (themeRegistry) default;
    description = "Selected visual theme.";
  };

  stylix = {
    enable = true;
    image = activeAssets.wallpaper;

    inherit (activeTheme) fonts polarity;
  }
  // lib.optionalAttrs (activeTheme ? colors) {
    base16Scheme = {
      system = "base16";
      name = activeTheme.label;
      variant = activeTheme.polarity;
      palette = activeTheme.colors;
    };
  }
  // lib.optionalAttrs isLinux {
    inherit (activeAssets) cursor;
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
    }
    // lib.optionalAttrs isLinux {
      fonts.fontconfig.defaultFonts.monospace = lib.mkAfter [
        "Symbols Nerd Font Mono"
        "Symbols Nerd Font"
      ];
    };

  home =
    {
      config,
      lib,
      ...
    }:
    {
      stylix.targets.qt.platform = "kde";
    }
    // lib.optionalAttrs isLinux {
      dconf.settings."org/gnome/desktop/interface".color-scheme = lib.mkForce (
        {
          light = "prefer-light";
          dark = "prefer-dark";
        }
        .${activeTheme.polarity} or "default"
      );
      gtk = {
        gtk4.theme = lib.mkDefault config.gtk.theme;
        iconTheme = activeAssets.icons;
      };
    };
  scopeEdits = {
    desktop = lib.optionalAttrs isLinux {
      hyprland = {
        home = _: {
          # Preserve GTK client headerbars while hiding toolkit window buttons.
          gtk.gtk3.extraConfig.gtk-decoration-layout = ":";
          gtk.gtk4.extraConfig.gtk-decoration-layout = ":";
          dconf.settings."org/gnome/desktop/wm/preferences".button-layout = ":";
        };
      };
    };
    cli = {
      bat = {
        home =
          {
            config,
            lib,
            pkgs,
            ...
          }:
          {
            stylix.targets.bat.enable = false;
            programs.bat = {
              config.theme = "stylix";
              themes.stylix.src = syntaxTheme { inherit config pkgs; };
            };

            home.sessionVariables = lib.mkIf config.programs.bat.enable {
              MANPAGER = "${lib.getExe config.programs.bat.package} -plman";
            };
          };
      };
      git = {
        delta = {
          home =
            {
              config,
              lib,
              pkgs,
              ...
            }:
            {
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

              xdg.configFile."bat/themes/stylix.tmTheme" =
                lib.mkIf (!config.programs.bat.enable && config.programs.delta.enable)
                  {
                    source = syntaxTheme { inherit config pkgs; };
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
            };
        };
        tuicr = {
          home =
            {
              config,
              pkgs,
              ...
            }:
            {
              xdg.configFile = {
                "tuicr/themes/stylix.tmTheme" = {
                  source = syntaxTheme { inherit config pkgs; };
                };

                "tuicr/themes/stylix.toml" = {
                  source = (pkgs.formats.toml { }).generate "tuicr-stylix-theme.toml" (
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
              };
            };
        };
      };
      gh = {
        home =
          {
            config,
            lib,
            pkgs,
            ...
          }:
          {
            xdg.configFile."gh-dash/stylix.yml" = lib.mkIf config.programs.gh.enable {
              source = (pkgs.formats.yaml { }).generate "gh-dash-stylix.yml" (
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
      };
      cava = {
        home =
          {
            config,

            ...
          }:
          {
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
    desktopApps = {
      chromium = lib.optionalAttrs isLinux {
        programs.chromium.initialPrefs.extensions.theme.system_theme = 2; # Qt
      };
      vscode = {
        home =
          _:
          {
            stylix.targets.vscode.enable = false;
          }
          // lib.optionalAttrs isLinux {
            programs.vscode.profiles.default.userSettings = {
              "window.titleBarStyle" = "custom";
              "window.controlsStyle" = "hidden";
            };
          };
      };
      zen = {
        home =
          { config, ... }:
          {
            programs.zen-browser.policies.Preferences = browserFontPolicy;
          }
          // lib.optionalAttrs isDarwin {
            home.file."Library/Application Support/Zen/Profiles/default/user.js".text = ''
              user_pref("font.name.serif.x-western", ${builtins.toJSON config.stylix.fonts.serif.name});
              user_pref("font.name.sans-serif.x-western", ${builtins.toJSON config.stylix.fonts.sansSerif.name});
              user_pref("font.name.monospace.x-western", ${builtins.toJSON config.stylix.fonts.monospace.name});
              user_pref("toolkit.legacyUserProfileCustomizations.stylesheets", true);
            '';
            home.file."Library/Application Support/Zen/Profiles/default/chrome/userChrome.css".text = ''
              @import url("zen-themes.css");

              ${import (inputs.stylix.outPath + "/modules/zen-browser/userChrome.nix") {
                colors = config.lib.stylix.colors;
                opacityHex = config.stylix.targets.zen-browser.opacityHex;
              }}

              :root,
              #navigator-toolbox,
              #sidebar-box,
              #urlbar-input,
              #urlbar-results,
              .tab-label,
              .toolbarbutton-text,
              .zen-workspace-name {
                font-family: ${builtins.toJSON config.stylix.fonts.sansSerif.name} !important;
              }
            '';
            home.file."Library/Application Support/Zen/Profiles/default/chrome/userContent.css".text =
              import (inputs.stylix.outPath + "/modules/zen-browser/userContent.nix")
                {
                  colors = config.lib.stylix.colors;
                  opacityHex = config.stylix.targets.zen-browser.opacityHex;
                };
          };
      };
      firefox = {
        home = _: {
          programs.firefox.policies.Preferences = browserFontPolicy;
          stylix.targets.firefox.profileNames = [ "themed" ];
          stylix.targets.firefox.colorTheme.enable = true;
          programs.firefox.profiles.themed = {
            extensions.force = true;
          }
          // lib.optionalAttrs isLinux {
            settings."toolkit.legacyUserProfileCustomizations.stylesheets" = true;
            userChrome = ''
              .titlebar-buttonbox-container, .titlebar-buttonbox { display: none !important; }
            '';
          };
        };
      };
      floorp = {
        home = _: {
          programs.floorp.policies.Preferences = browserFontPolicy;
          stylix.targets.floorp.profileNames = [ "themed" ];
          stylix.targets.floorp.colorTheme.enable = true;
          programs.floorp.profiles.themed = {
            extensions.force = true;
          }
          // lib.optionalAttrs isLinux {
            settings."toolkit.legacyUserProfileCustomizations.stylesheets" = true;
            userChrome = ''
              .titlebar-buttonbox-container, .titlebar-buttonbox { display: none !important; }
            '';
          };
        };
      };
    };
  };

}
