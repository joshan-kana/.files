{ inputs, pkgs, ... }:

{
  brave = _: {
    environment.systemPackages = [ pkgs.brave ];
  };

  bitwarden = _: {
    environment.systemPackages = [ pkgs.bitwarden-desktop ];
  };

  warp = _: {
    environment.systemPackages = [ pkgs.warp-terminal ];
  };

  mullvad = _: {
    services.mullvad-vpn.enable = true;
    environment.systemPackages = [ pkgs.mullvad-vpn ];
  };

  chromium = _: {
    environment.systemPackages = [ pkgs.chromium ];
  };

  zen = _: {
    environment.systemPackages = [
      inputs.zen-browser.packages.${pkgs.stdenv.hostPlatform.system}.beta
    ];
  };

  firefox = _: {
    home = _: {
      stylix.targets.firefox.profileNames = [ "themed" ];
      stylix.targets.firefox.colorTheme.enable = true;
      programs.firefox.profiles.themed.extensions.force = true;
      programs.firefox.configPath = ".mozilla/firefox";
    };
  };

  floorp = _: {
    home = _: {
      stylix.targets.floorp.profileNames = [ "themed" ];
      stylix.targets.floorp.colorTheme.enable = true;
      programs.floorp.profiles.themed.extensions.force = true;
    };
  };

  kitty = _: {
    home = _: {
      programs.kitty.extraConfig = ''
        confirm_os_window_close 0
        enable_audio_bell no
        input_delay 0
        touch_scroll_multiplier 3.0
      '';
    };
  };

  alacritty = _: {
    home =
      {
        config,
        lib,
        osConfig,
        pkgs,
        ...
      }:
      let
        runtimeThemeSwitching = osConfig.dotfiles.theme.runtimeSwitching;
        stateDir = "${config.xdg.stateHome}/dotfiles/theme";
      in
      {
        stylix.targets.alacritty.enable = !runtimeThemeSwitching;

        programs.alacritty.settings = lib.mkIf runtimeThemeSwitching {
          general.import = [ "${stateDir}/alacritty.toml" ];
          font.size = config.stylix.fonts.sizes.terminal;
          window.opacity = config.stylix.opacity.terminal;
        };

        xdg.configFile."dotfiles/theme-hooks/10-alacritty".source = lib.mkIf runtimeThemeSwitching (
          pkgs.writeShellScript "dotfiles-theme-alacritty" ''
            theme="$1/theme.json"
            tmp=${lib.escapeShellArg stateDir}/alacritty.toml.tmp.$$

            install -d -m 0700 ${lib.escapeShellArg stateDir}
            ${pkgs.jq}/bin/jq -r '
              [
                "[colors.primary]",
                "background = \"#\(.colors.base00)\"",
                "foreground = \"#\(.colors.base05)\"",
                "bright_foreground = \"#\(.colors.base07)\"",
                "",
                "[colors.cursor]",
                "text = \"#\(.colors.base00)\"",
                "cursor = \"#\(.colors.base05)\"",
                "",
                "[colors.selection]",
                "text = \"#\(.colors.base05)\"",
                "background = \"#\(.colors.base02)\"",
                "",
                "[colors.normal]",
                "black = \"#\(.colors.base00)\"",
                "red = \"#\(.colors.base08)\"",
                "green = \"#\(.colors.base0B)\"",
                "yellow = \"#\(.colors.base0A)\"",
                "blue = \"#\(.colors.base0D)\"",
                "magenta = \"#\(.colors.base0E)\"",
                "cyan = \"#\(.colors.base0C)\"",
                "white = \"#\(.colors.base05)\"",
                "",
                "[colors.bright]",
                "black = \"#\(.colors.base03)\"",
                "red = \"#\(.colors.base08)\"",
                "green = \"#\(.colors.base0B)\"",
                "yellow = \"#\(.colors.base0A)\"",
                "blue = \"#\(.colors.base0D)\"",
                "magenta = \"#\(.colors.base0E)\"",
                "cyan = \"#\(.colors.base0C)\"",
                "white = \"#\(.colors.base07)\"",
                "",
                "[font.normal]",
                "family = \(.fonts.monospace.name | @json)",
                "style = \"Regular\""
              ] | join("\n")
            ' "$theme" > "$tmp"
            chmod 0600 "$tmp"
            mv -f "$tmp" ${lib.escapeShellArg stateDir}/alacritty.toml
          ''
        );
      };
  };

  thunderbird = _: {
    environment.systemPackages = [ pkgs.thunderbird ];
  };

  obsidian = _: {
    environment.systemPackages = [ pkgs.obsidian ];
  };

  filelight = _: {
    environment.systemPackages = [ pkgs.kdePackages.filelight ];
  };

  gimp = _: {
    environment.systemPackages = [ pkgs.gimp ];
  };

  gparted = _: {
    environment.systemPackages = [ pkgs.gparted ];
  };

  githubDesktop = _: {
    environment.systemPackages = [ pkgs.github-desktop ];
  };

  nautilus = _: {
    environment.systemPackages = [ pkgs.nautilus ];
  };

  vscode = _: {
    home = _: {
      programs.vscode = { };
    };
  };

  pycharm = _: {
    environment.systemPackages = [ pkgs.jetbrains.pycharm ];
  };

  libreoffice = _: {
    environment.systemPackages = [ pkgs.libreoffice ];
  };

  sunshine = _: {
    environment.systemPackages = [ pkgs.sunshine ];
    networking.firewall.allowedTCPPorts = [ 47990 ];
  };

  moonlight = _: {
    environment.systemPackages = [ pkgs.moonlight-qt ];
  };

  waypipe = _: {
    environment.systemPackages = [ pkgs.waypipe ];
  };

  vlc = _: {
    environment.systemPackages = [ pkgs.vlc ];
  };

  mopidy = _: {
    home = _: {
      services.mopidy = {
        enable = false;
        extensionPackages = with pkgs; [
          mopidy-mpd
          mopidy-mpris
        ];
        settings.mpd = {
          enabled = true;
          hostname = "127.0.0.1";
          port = "6600";
        };
      };
    };
  };

  # The local Ollama service is managed outside this shared module, but these
  # desktop hosts intentionally expose its established ports.
  ollama = _: {
    networking.firewall.allowedTCPPorts = [
      11434
      11435
    ];
  };
  spotify =
    { lib, options, ... }:
    lib.optionalAttrs (lib.hasAttrByPath [ "programs" "spicetify" ] options) {
      programs.spicetify.enable = true;
    };

  discord = _: {
    environment.systemPackages = [ pkgs.discord ];
  };

  dropbox = _: {
    environment.systemPackages = [ pkgs.dropbox ];
  };

  onlyoffice = _: {
    environment.systemPackages = [ pkgs.onlyoffice-desktopeditors ];
  };

  twingate = _: {
    services.twingate.enable = true;
  };

}
