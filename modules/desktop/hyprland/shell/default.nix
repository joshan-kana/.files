{
  lib,
  scopeConfig,
  ...
}:

{
  enable = false;

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
      shellPath = "${osConfig.dotfiles.paths.repoPath}/modules/desktop/hyprland/shell/qml";
      json = pkgs.formats.json { };
      colors = config.lib.stylix.colors.withHashtag;
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
        wallpaper = toString osConfig.stylix.image;
      };

      launcher = pkgs.writeShellApplication {
        name = "linux-desktop";
        runtimeInputs = [ pkgs.quickshell ];
        text = ''
          export LINUX_DESKTOP_RUNTIME="''${XDG_CONFIG_HOME:-$HOME/.config}/linux-desktop/runtime.json"
          exec qs --path ${lib.escapeShellArg shellPath} "$@"
        '';
      };
    in
    {
      home.packages = [
        launcher
        pkgs.quickshell
      ];

      xdg.configFile."linux-desktop/runtime.json".source = runtimeConfig;

      systemd.user.services.linux-desktop = {
        Unit = {
          Description = "Hyprland desktop shell";
          PartOf = [ "hyprland-session.target" ];
          After = [ "hyprland-session.target" ];
        };

        Service = {
          ExecStart = "${lib.getExe launcher} --no-duplicate";
          Restart = "on-failure";
          RestartSec = 1;
        };

        Install.WantedBy = [ "hyprland-session.target" ];
      };
    };
}
