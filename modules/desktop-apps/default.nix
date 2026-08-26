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
    home = _: {
      programs.alacritty = { };
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
}
