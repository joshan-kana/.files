{
  lib,
  scopeConfig,
  ...
}:

{
  scopeOptions.animationsEnabled = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = "Enable motion and animated transitions in the Hyprland desktop shell.";
  };

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

      keybindings = import ../keybindings.nix {
        repoPath = osConfig.dotfiles.paths.repoPath;
        terminal = osConfig.dotfiles.defaults.terminal;
      };

      cheatsheetBindings = map (binding: {
        key =
          if binding.label != null then
            binding.label
          else
            "${lib.optionalString binding.mainMod "SUPER + "}${binding.keys}";
        inherit (binding) description section;
      }) (lib.filter (binding: binding.cheatsheet) keybindings);

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

        motion.animationsEnabled = scopeConfig.animationsEnabled;
        keybindings = cheatsheetBindings;

        tools = {
          brightnessctl = lib.getExe pkgs.brightnessctl;
          cliphist = lib.getExe pkgs.cliphist;
          clipboardCopy = lib.getExe clipboardCopy;
          lockSession = lib.getExe lockCommand;
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
    in
    {
      home.packages = [
        launcher
        developmentLauncher
        lockCommand
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
            Requires = [ "linux-desktop-spectrum.service" ];
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
