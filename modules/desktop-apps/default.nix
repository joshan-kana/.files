{
  inputs,
  lib,
  pkgs,
  system,
  ...
}:

let
  inherit (lib.systems.elaborate system) isDarwin isLinux;
in
{
  brave = _: {
    environment.systemPackages = [ pkgs.brave ];
  };

  bitwarden = _: {
    environment.systemPackages = [ pkgs.bitwarden-desktop ];
  };

  warp =
    _:
    (
      lib.optionalAttrs isLinux {
        environment.systemPackages = [ pkgs.warp-terminal ];
      }
      // lib.optionalAttrs isDarwin {
        homebrew.casks = [ "warp" ];
      }
    );

  mullvad =
    _:
    lib.optionalAttrs isLinux {
      environment.systemPackages = [ pkgs.mullvad-vpn ];
      services.mullvad-vpn.enable = true;
    }
    // lib.optionalAttrs isDarwin {
      homebrew.casks = [ "mullvad-vpn" ];
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
      programs.floorp = { };
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

  githubDesktop = _: {
    config = lib.optionalAttrs isLinux {
      environment.systemPackages = [ pkgs.github-desktop ];
    };
  };

  vscode = _: {
    environment.systemPackages = [ pkgs.vscode ];
    home = _: {
      programs.vscode = { };
    };
  };

  pycharm = _: {
    environment.systemPackages = [ pkgs.jetbrains.pycharm ];
  };

  libreoffice =
    _:
    (
      lib.optionalAttrs isLinux {
        environment.systemPackages = [ pkgs.libreoffice ];
      }
      // lib.optionalAttrs isDarwin {
        homebrew.casks = [ "libreoffice" ];
      }
    );

  sunshine = _: {
    environment.systemPackages = [ pkgs.sunshine ];
    config = lib.optionalAttrs isLinux {
      networking.firewall.allowedTCPPorts = [ 47990 ];
    };
  };

  moonlight = _: {
    environment.systemPackages = [ pkgs.moonlight-qt ];
  };

  jellyfin = _: {
    environment.systemPackages = [
      (if isDarwin then pkgs.jellyfin-desktop else pkgs.jellyfin-mpv-shim)
    ];
  };

  vlc =
    _:
    (
      lib.optionalAttrs isLinux {
        environment.systemPackages = [ pkgs.vlc ];
      }
      // lib.optionalAttrs isDarwin {
        homebrew.casks = [ "vlc" ];
      }
    );

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

  ollama =
    _:
    (
      lib.optionalAttrs isLinux {
        networking.firewall.allowedTCPPorts = [
          11434
          11435
        ];
      }
      // lib.optionalAttrs isDarwin {
        environment.systemPackages = [ pkgs.ollama ];
        launchd.user.agents.ollama.serviceConfig = {
          ProgramArguments = [
            (lib.getExe pkgs.ollama)
            "serve"
          ];
          RunAtLoad = true;
          KeepAlive = true;
          # Preserve the previous IPv4/IPv6 LAN listener.
          EnvironmentVariables.OLLAMA_HOST = "[::]:11434";
        };
      }
    );

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
// lib.optionalAttrs isLinux {
  filelight = _: {
    environment.systemPackages = [ pkgs.kdePackages.filelight ];
  };
  gparted = _: {
    environment.systemPackages = [ pkgs.gparted ];
  };
  nautilus = _: {
    environment.systemPackages = [ pkgs.nautilus ];
  };
  waypipe = _: {
    environment.systemPackages = [ pkgs.waypipe ];
  };
}
