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
  brave =
    _:
    {
      config = lib.optionalAttrs isLinux {
        environment.systemPackages = [ pkgs.brave ];
      };
    }
    // lib.optionalAttrs isDarwin {
      homebrew.casks = [ "brave-browser" ];
    };

  bitwarden =
    _:
    {
      config = lib.optionalAttrs isLinux {
        environment.systemPackages = [ pkgs.bitwarden-desktop ];
      };
    }
    // lib.optionalAttrs isDarwin {
      homebrew.casks = [ "bitwarden" ];
    };

  warp =
    _:
    {
      config = lib.optionalAttrs isLinux {
        environment.systemPackages = [ pkgs.warp-terminal ];
      };
    }
    // lib.optionalAttrs isDarwin {
      homebrew.casks = [ "warp" ];
    };

  mullvad =
    _:
    {
      config = lib.optionalAttrs isLinux {
        services.mullvad-vpn.enable = true;
        environment.systemPackages = [ pkgs.mullvad-vpn ];
      };
    }
    // lib.optionalAttrs isDarwin {
      homebrew.casks = [ "mullvad-vpn" ];
    };

  chromium =
    _:
    {
      config = lib.optionalAttrs isLinux {
        environment.systemPackages = [ pkgs.chromium ];
      };
    }
    // lib.optionalAttrs isDarwin {
      homebrew.casks = [ "chromium" ];
    };

  zen =
    _:
    {
      config = lib.optionalAttrs isLinux {
        environment.systemPackages = [
          inputs.zen-browser.packages.${pkgs.stdenv.hostPlatform.system}.beta
        ];
      };
    }
    // lib.optionalAttrs isDarwin {
      homebrew.casks = [ "zen" ];
    };

  firefox =
    _:
    {
      home = _: {
        stylix.targets.firefox.profileNames = [ "themed" ];
        stylix.targets.firefox.colorTheme.enable = true;
        programs.firefox.profiles.themed.extensions.force = true;
        programs.firefox.package = lib.mkIf isDarwin null;
        programs.firefox.configPath =
          lib.optionalString isDarwin "Library/Application Support/Firefox"
          + lib.optionalString isLinux ".mozilla/firefox";
      };
    }
    // lib.optionalAttrs isDarwin {
      homebrew.casks = [ "firefox" ];
    };

  floorp =
    _:
    {
      home = _: {
        stylix.targets.floorp.profileNames = [ "themed" ];
        stylix.targets.floorp.colorTheme.enable = true;
        programs.floorp.profiles.themed.extensions.force = true;
        programs.floorp.package = lib.mkIf isDarwin null;
      };
    }
    // lib.optionalAttrs isDarwin {
      homebrew.casks = [ "floorp" ];
    };

  kitty =
    _:
    {
      home = _: {
        programs.kitty.extraConfig = ''
          confirm_os_window_close 0
          enable_audio_bell no
          input_delay 0
          touch_scroll_multiplier 3.0
        '';
      };
    }
    // lib.optionalAttrs isDarwin {
      homebrew.casks = [ "kitty" ];
    };

  alacritty = _: {
    home = _: {
      programs.alacritty = { };
    };
  };

  thunderbird =
    _:
    {
      config = lib.optionalAttrs isLinux {
        environment.systemPackages = [ pkgs.thunderbird ];
      };
    }
    // lib.optionalAttrs isDarwin {
      homebrew.casks = [ "thunderbird" ];
    };

  obsidian =
    _:
    {
      config = lib.optionalAttrs isLinux {
        environment.systemPackages = [ pkgs.obsidian ];
      };
    }
    // lib.optionalAttrs isDarwin {
      homebrew.casks = [ "obsidian" ];
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

  githubDesktop =
    _:
    {
      config = lib.optionalAttrs isLinux {
        environment.systemPackages = [ pkgs.github-desktop ];
      };
    }
    // lib.optionalAttrs isDarwin {
      homebrew.casks = [ "github" ];
    };

  nautilus = linuxOnly (_: {
    environment.systemPackages = [ pkgs.nautilus ];
  });

  vscode = _: {
    home = _: {
      programs.vscode = { };
    };
  };

  pycharm =
    _:
    {
      config = lib.optionalAttrs isLinux {
        environment.systemPackages = [ pkgs.jetbrains.pycharm ];
      };
    }
    // lib.optionalAttrs isDarwin {
      homebrew.casks = [ "pycharm" ];
    };

  libreoffice =
    _:
    {
      config = lib.optionalAttrs isLinux {
        environment.systemPackages = [ pkgs.libreoffice ];
      };
    }
    // lib.optionalAttrs isDarwin {
      homebrew.casks = [ "libreoffice" ];
    };

  sunshine = _: {
    environment.systemPackages = [ pkgs.sunshine ];
    config = lib.optionalAttrs isLinux {
      networking.firewall.allowedTCPPorts = [ 47990 ];
    };
  };

  moonlight =
    _:
    {
      config = lib.optionalAttrs isLinux {
        environment.systemPackages = [ pkgs.moonlight-qt ];
      };
    }
    // lib.optionalAttrs isDarwin {
      homebrew.casks = [ "moonlight" ];
    };

  waypipe = linuxOnly (_: {
    environment.systemPackages = [ pkgs.waypipe ];
  });

  vlc =
    _:
    {
      config = lib.optionalAttrs isLinux {
        environment.systemPackages = [ pkgs.vlc ];
      };
    }
    // lib.optionalAttrs isDarwin {
      homebrew.casks = [ "vlc" ];
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
      homebrew.casks = [ "spotify" ];
    };

  discord =
    _:
    {
      config = lib.optionalAttrs isLinux {
        environment.systemPackages = [ pkgs.discord ];
      };
    }
    // lib.optionalAttrs isDarwin {
      homebrew.casks = [ "discord" ];
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

  onlyoffice =
    _:
    {
      config = lib.optionalAttrs isLinux {
        environment.systemPackages = [ pkgs.onlyoffice-desktopeditors ];
      };
    }
    // lib.optionalAttrs isDarwin {
      homebrew.casks = [ "onlyoffice" ];
    };

  twingate =
    _:
    {
      config = lib.optionalAttrs isLinux {
        services.twingate.enable = true;
      };
    }
    // lib.optionalAttrs isDarwin {
      homebrew.casks = [ "twingate" ];
    };

}
