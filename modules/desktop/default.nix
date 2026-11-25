{ lib, system, ... }:

let
  inherit (lib.systems.elaborate system) isDarwin isLinux;
in
{
  # Shared graphical-session infrastructure. Applications, audio, and
  # virtualisation live at the top semantic level instead of under desktop.
  /**
    Linux graphical-session integration.
  */
  linuxSession =
    _:
    lib.optionalAttrs isLinux {
      services.gvfs.enable = true;
      environment.sessionVariables.NIXOS_OZONE_WL = "1";
    };

  /**
    Shared X server compatibility support.
  */
  xserver = _: lib.optionalAttrs isLinux ((import ./xserver) { });
  /**
    Display-manager policy shared by graphical hosts.
  */
  displayManager = _: lib.optionalAttrs isLinux ((import ./display-manager) { });
  /**
    Hyprland desktop session and its host integration.
  */
  hyprland =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    lib.optionalAttrs isLinux ((import ./hyprland) { inherit config lib pkgs; });
  /**
    KDE Plasma desktop session and generated Plasma Manager state.
  */
  plasma =
    {
      config,
      inputs,
      lib,
      ...
    }:
    lib.optionalAttrs isLinux ((import ./plasma) { inherit config inputs lib; });

  /**
    Full-screen television session with a lightweight compositor and media launcher.
  */
  mediaSession =
    {
      config,
      lib,
      pkgs,
      scopeConfig,
      ...
    }:
    lib.optionalAttrs isLinux (
      {
        scopeOptions.nativeKodi = lib.mkOption {
          type = lib.types.nullOr lib.types.package;
          default = null;
          description = "Kodi package requiring exclusive DRM display ownership.";
        };
      }
      // (import ./media-session) {
        inherit config lib pkgs;
        inherit (scopeConfig) nativeKodi;
      }
    );

  # Keep GNOME available as an opt-in desktop without changing current hosts.
  /**
    Optional GNOME desktop session.
  */
  gnome = _: lib.optionalAttrs isLinux ((import ./gnome) { });

  /**
    Native macOS keyboard remapping and event handling.
  */
  karabinerElements = _: lib.optionalAttrs isDarwin ((import ./karabiner) { });

  /**
    macOS automation, window management, and keyboard shortcuts.
  */
  hammerspoon =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    lib.optionalAttrs isDarwin (
      (import ./hammerspoon) {
        inherit lib pkgs;
        inherit (config.dotfiles.defaults) browser terminal;
      }
    );

  /**
    Raycast launcher and system command palette.
  */
  raycast =
    { pkgs, ... }:
    lib.optionalAttrs isDarwin {
      home = _: {
        home.packages = [ pkgs.raycast ];
      };
    };

  /**
    macOS tiling window management.
  */
  yabai = _: lib.optionalAttrs isDarwin ((import ./yabai) { });

  /**
    macOS battery charging management.
  */
  aldente =
    { pkgs, ... }:
    lib.optionalAttrs isDarwin {
      home = _: {
        home.packages = [ pkgs.aldente ];
      };
    };

  /**
    macOS keyboard-controlled pointer navigation.
  */
  homerow =
    { pkgs, ... }:
    lib.optionalAttrs isDarwin {
      home = _: {
        home.packages = [ pkgs.homerow ];
      };
    };

  /**
    macOS menu bar item management.
  */
  iceBar =
    { pkgs, ... }:
    lib.optionalAttrs isDarwin {
      home = _: {
        home.packages = [ pkgs.ice-bar ];
      };
    };

  /**
    macOS pointer and scrolling adjustments.
  */
  linearmouse =
    { pkgs, ... }:
    lib.optionalAttrs isDarwin {
      home = _: {
        home.packages = [ pkgs.linearmouse ];
      };
    };

  /**
    Logitech device configuration using its vendor installer.
  */
  logiOptions =
    _:
    lib.optionalAttrs isDarwin {
      homebrew.casks = [ "logi-options+" ];
    };
}
