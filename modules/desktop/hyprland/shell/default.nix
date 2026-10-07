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

      apply_theme() {
        selected="$1"

        if [ "''${USER:-}" != "$expectedUser" ]; then
          printf 'theme-set is configured for user %s, not %s\n' "$expectedUser" "''${USER:-unknown}" >&2
          exit 1
        fi

        if ! resolve_theme "$selected"; then
          printf 'Unknown theme: %s\n' "$selected" >&2
          exit 2
        fi

        activation="$(
          nix build \
            --no-link \
            --print-out-paths \
            "$themeFlake#nixosConfigurations.${configurationName}-$selected.config.home-manager.users.${primaryUser}.home.activationPackage"
        )"

        XDG_DATA_DIRS="$activation/home-path/share''${XDG_DATA_DIRS:+:$XDG_DATA_DIRS}" \
          "$activation/activate" --driver-version 1

        write_state "$selected"
        printf '%s\n' "$selected"
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
          printf 'Usage: theme-set [list [--json]|current|restore|<theme>]\n' >&2
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

  assertions = [
    {
      assertion = scopeConfig.textScale >= 0.75 && scopeConfig.textScale <= 1.5;
      message = "desktop.hyprland.shell.textScale must be between 0.75 and 1.5";
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

      spectrumFieldShader =
        pkgs.runCommand "linux-desktop-spectrum-field.frag.qsb"
          {
            nativeBuildInputs = [ pkgs.qt6.qtshadertools ];
          }
          ''
            qsb --qt6 ${./qml/spectrum-field.frag} -o "$out"
          '';

      keybindings = import ../keybindings.nix {
        terminal = osConfig.dotfiles.defaults.terminal;
      };
      mainModifierLabel = "HYPER";

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

        fonts = {
          sans = config.stylix.fonts.sansSerif.name;
          mono = config.stylix.fonts.monospace.name;
        };

        assets.spectrumFieldShader = "file://${spectrumFieldShader}";

        accessibility.textScale = scopeConfig.textScale;
        motion.animationsEnabled = scopeConfig.animationsEnabled;
        visual = shellVisual;
        keybindings = cheatsheetBindings;
        inherit shortcuts;

        tools = {
          bluetoothctl = lib.getExe' pkgs.bluez "bluetoothctl";
          brightnessctl = lib.getExe pkgs.brightnessctl;
          cliphist = lib.getExe pkgs.cliphist;
          clipboardCopy = lib.getExe clipboardCopy;
          lockSession = lib.getExe lockCommand;
          networkConnectionEditor = lib.getExe' pkgs.networkmanagerapplet "nm-connection-editor";
          sessionCommand = lib.getExe sessionCommand;
          themeSet = lib.getExe themeSet;
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
      home.packages = [
        launcher
        developmentLauncher
        lockCommand
        sessionCommand
        clipboardCopy
        pkgs.quickshell
        spectrumAnalyzer
      ];

      xdg.configFile."linux-desktop/runtime.json".source = runtimeConfig;

      systemd.user.services = {
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
      };
    };
}
