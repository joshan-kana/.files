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
        stylix.targets.alacritty.enable = lib.mkIf runtimeThemeSwitching (lib.mkForce false);

        programs.alacritty.settings = lib.mkIf runtimeThemeSwitching {
          general.import = [ "${stateDir}/alacritty.toml" ];
          font.size = config.stylix.fonts.sizes.terminal;
          window.opacity = config.stylix.opacity.terminal;
        };

        xdg.configFile."dotfiles/theme-hooks/10-alacritty".source = lib.mkIf runtimeThemeSwitching (
          pkgs.writeShellScript "dotfiles-theme-alacritty" ''
            pack="$1"
            theme="$pack/theme.json"
            tmp=${lib.escapeShellArg stateDir}/alacritty.toml.tmp.$$

            color() {
              ${pkgs.jq}/bin/jq -r --arg key "$1" '.colors[$key]' "$theme"
            }

            fontName="$(${pkgs.jq}/bin/jq -r '.fonts.monospace.name' "$theme")"
            base00="$(color base00)"
            base02="$(color base02)"
            base03="$(color base03)"
            base05="$(color base05)"
            base07="$(color base07)"
            base08="$(color base08)"
            base0A="$(color base0A)"
            base0B="$(color base0B)"
            base0C="$(color base0C)"
            base0D="$(color base0D)"
            base0E="$(color base0E)"

            install -d -m 0700 ${lib.escapeShellArg stateDir}
            cat > "$tmp" <<EOF
            [colors.primary]
            background = "#$base00"
            foreground = "#$base05"
            bright_foreground = "#$base07"

            [colors.cursor]
            text = "#$base00"
            cursor = "#$base05"

            [colors.selection]
            text = "#$base05"
            background = "#$base02"

            [colors.normal]
            black = "#$base00"
            red = "#$base08"
            green = "#$base0B"
            yellow = "#$base0A"
            blue = "#$base0D"
            magenta = "#$base0E"
            cyan = "#$base0C"
            white = "#$base05"

            [colors.bright]
            black = "#$base03"
            red = "#$base08"
            green = "#$base0B"
            yellow = "#$base0A"
            blue = "#$base0D"
            magenta = "#$base0E"
            cyan = "#$base0C"
            white = "#$base07"

            [font.normal]
            family = "$fontName"
            style = "Regular"
            EOF
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
