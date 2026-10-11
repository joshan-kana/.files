{
  inputs,
  lib,
  pkgs,
  system,
  ...
}:

let
  inherit (lib.systems.elaborate system) isLinux;
  linuxOnly =
    scope: lib.setFunctionArgs (args: lib.optionalAttrs isLinux (scope args)) (lib.functionArgs scope);
in
{
  brave = linuxOnly (_: {
    environment.systemPackages = [ pkgs.brave ];
  });

  bitwarden = linuxOnly (_: {
    environment.systemPackages = [ pkgs.bitwarden-desktop ];
  });

  warp = linuxOnly (_: {
    environment.systemPackages = [ pkgs.warp-terminal ];
  });

  mullvad = linuxOnly (_: {
    services.mullvad-vpn.enable = true;
    environment.systemPackages = [ pkgs.mullvad-vpn ];
  });

  chromium = linuxOnly (_: {
    environment.systemPackages = [ pkgs.chromium ];
  });

  zen = linuxOnly (_: {
    environment.systemPackages = [
      inputs.zen-browser.packages.${pkgs.stdenv.hostPlatform.system}.beta
    ];
  });

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

  thunderbird = linuxOnly (_: {
    environment.systemPackages = [ pkgs.thunderbird ];
  });

  obsidian = linuxOnly (_: {
    environment.systemPackages = [ pkgs.obsidian ];
  });

  filelight = linuxOnly (_: {
    environment.systemPackages = [ pkgs.kdePackages.filelight ];
  });

  gimp = linuxOnly (_: {
    environment.systemPackages = [ pkgs.gimp ];
  });

  gparted = linuxOnly (_: {
    environment.systemPackages = [ pkgs.gparted ];
  });

  githubDesktop = linuxOnly (_: {
    environment.systemPackages = [ pkgs.github-desktop ];
  });

  nautilus = linuxOnly (_: {
    environment.systemPackages = [ pkgs.nautilus ];
  });

  vscode = _: {
    home = _: {
      programs.vscode = { };
    };
  };

  pycharm = linuxOnly (_: {
    environment.systemPackages = [ pkgs.jetbrains.pycharm ];
  });

  libreoffice = linuxOnly (_: {
    environment.systemPackages = [ pkgs.libreoffice ];
  });

  sunshine = linuxOnly (_: {
    environment.systemPackages = [ pkgs.sunshine ];
    networking.firewall.allowedTCPPorts = [ 47990 ];
  });

  moonlight = linuxOnly (_: {
    environment.systemPackages = [ pkgs.moonlight-qt ];
  });

  waypipe = linuxOnly (_: {
    environment.systemPackages = [ pkgs.waypipe ];
  });

  vlc = linuxOnly (_: {
    environment.systemPackages = [ pkgs.vlc ];
  });

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
  ollama = linuxOnly (_: {
    networking.firewall.allowedTCPPorts = [
      11434
      11435
    ];
  });
  spotify = linuxOnly (
    { lib, options, ... }:
    lib.optionalAttrs (lib.hasAttrByPath [ "programs" "spicetify" ] options) {
      programs.spicetify.enable = true;
    }
  );

  discord = linuxOnly (_: {
    environment.systemPackages = [ pkgs.discord ];
  });

  dropbox = linuxOnly (_: {
    environment.systemPackages = [ pkgs.dropbox ];
  });

  onlyoffice = linuxOnly (_: {
    environment.systemPackages = [ pkgs.onlyoffice-desktopeditors ];
  });

  twingate = linuxOnly (_: {
    services.twingate.enable = true;
  });

}
