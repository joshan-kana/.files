{
  inputs,
  lib,
  pkgs,
  system,
  ...
}:

let
  inherit (lib.systems.elaborate system) isDarwin isLinux;
  linuxOnly =
    scope: lib.setFunctionArgs (args: lib.optionalAttrs isLinux (scope args)) (lib.functionArgs scope);
in
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

  mullvad =
    _:
    {
      environment.systemPackages =
        if isDarwin then
          [ pkgs.mullvad ]
        else if isLinux then
          [ pkgs.mullvad-vpn ]
        else
          [ ];
    }
    // lib.optionalAttrs isLinux {
      services.mullvad-vpn.enable = true;
    };

  chromium = _: {
    config = lib.optionalAttrs isLinux {
      environment.systemPackages = [ pkgs.chromium ];
    };
  };

  zen = _: {
    environment.systemPackages = [ inputs.zen-browser.packages.${system}.beta ];
  };

  firefox = _: {
    environment.systemPackages = lib.optionals isDarwin [ pkgs.firefox-bin ];
    home = _: {
      programs.firefox.package = if isDarwin then pkgs.firefox-bin else pkgs.firefox;
      stylix.targets.firefox.profileNames = [ "themed" ];
      stylix.targets.firefox.colorTheme.enable = true;
      programs.firefox.profiles.themed.extensions.force = true;
      programs.firefox.configPath =
        if isDarwin then
          "Library/Application Support/Firefox"
        else if isLinux then
          ".mozilla/firefox"
        else
          null;
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
    environment.systemPackages = [ (if isDarwin then pkgs.thunderbird-bin else pkgs.thunderbird) ];
  };

  obsidian = _: {
    environment.systemPackages = [ pkgs.obsidian ];
  };

  filelight = linuxOnly (_: {
    environment.systemPackages = [ pkgs.kdePackages.filelight ];
  });

  gimp =
    _:
    {
      config = lib.optionalAttrs isLinux {
        environment.systemPackages = [ pkgs.gimp ];
      };
    }
    // lib.optionalAttrs isDarwin {
      homebrew.casks = [ "gimp" ];
    };

  gparted = linuxOnly (_: {
    environment.systemPackages = [ pkgs.gparted ];
  });

  githubDesktop = _: {
    config = lib.optionalAttrs isLinux {
      environment.systemPackages = [ pkgs.github-desktop ];
    };
  };

  nautilus = linuxOnly (_: {
    environment.systemPackages = [ pkgs.nautilus ];
  });

  vscode = _: {
    environment.systemPackages = [ pkgs.vscode ];
    home = _: {
      programs.vscode = { };
    };
  };

  pycharm = _: {
    environment.systemPackages = [ pkgs.jetbrains.pycharm ];
  };

  libreoffice = _: {
    environment.systemPackages =
      if isDarwin then
        [ pkgs.libreoffice-bin ]
      else if isLinux then
        [ pkgs.libreoffice ]
      else
        [ ];
  };

  sunshine = _: {
    environment.systemPackages = [ pkgs.sunshine ];
    config = lib.optionalAttrs isLinux {
      networking.firewall.allowedTCPPorts = [ 47990 ];
    };
  };

  moonlight = _: {
    environment.systemPackages = [ pkgs.moonlight-qt ];
  };

  waypipe = linuxOnly (_: {
    environment.systemPackages = [ pkgs.waypipe ];
  });

  vlc = _: {
    environment.systemPackages =
      if isDarwin then
        [ pkgs.vlc-bin ]
      else if isLinux then
        [ pkgs.vlc ]
      else
        [ ];
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
  ollama = linuxOnly (_: {
    networking.firewall.allowedTCPPorts = [
      11434
      11435
    ];
  });
  spotify =
    { lib, options, ... }:
    (lib.optionalAttrs isLinux (
      lib.optionalAttrs (lib.hasAttrByPath [ "programs" "spicetify" ] options) {
        programs.spicetify.enable = true;
      }
    ))
    // lib.optionalAttrs isDarwin {
      # The pinned Darwin Nixpkgs source depends on a stalled Wayback download.
      homebrew.casks = [ "spotify" ];
    };

  discord = _: {
    environment.systemPackages = [ pkgs.discord ];
  };

  dropbox =
    _:
    {
      config = lib.optionalAttrs isLinux {
        environment.systemPackages = [ pkgs.dropbox ];
      };
    }
    // lib.optionalAttrs isDarwin {
      homebrew.casks = [ "dropbox" ];
    };

  onlyoffice = _: {
    config = lib.optionalAttrs isLinux {
      environment.systemPackages = [ pkgs.onlyoffice-desktopeditors ];
    };
  };

  twingate = _: {
    config = lib.optionalAttrs isLinux {
      services.twingate.enable = true;
    };
  };

}
