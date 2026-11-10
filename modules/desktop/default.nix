{ lib, system, ... }:

let
  inherit (lib.systems.elaborate system) isDarwin isLinux;
  linuxScope =
    scope: lib.setFunctionArgs (args: lib.optionalAttrs isLinux (scope args)) (lib.functionArgs scope);
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
  xserver = linuxScope (import ./xserver);
  /**
    Display-manager policy shared by graphical hosts.
  */
  displayManager = linuxScope (import ./display-manager);
  /**
    Hyprland desktop session and its host integration.
  */
  hyprland = linuxScope (import ./hyprland);
  /**
    KDE Plasma desktop session and generated Plasma Manager state.
  */
  plasma = linuxScope (import ./plasma);

  # Keep GNOME available as an opt-in desktop without changing current hosts.
  /**
    Optional GNOME desktop session.
  */
  gnome = linuxScope (import ./gnome);

  /**
    Native macOS keyboard remapping and event handling.
  */
  karabinerElements = _: lib.optionalAttrs isDarwin ((import ./karabiner) { });

  /**
    macOS automation, window management, and keyboard shortcuts.
  */
  hammerspoon =
    { lib, pkgs, ... }: lib.optionalAttrs isDarwin ((import ./hammerspoon) { inherit lib pkgs; });

  /**
    Raycast launcher and system command palette.
  */
  raycast =
    { pkgs, ... }:
    lib.optionalAttrs isDarwin {
      home = _: { home.packages = [ pkgs.raycast ]; };
    };

  /**
    macOS tiling window management.
  */
  yabai = { lib, system, ... }: lib.optionalAttrs isDarwin ((import ./yabai) { inherit lib system; });

  /**
    macOS battery charging management.
  */
  aldente =
    { pkgs, ... }:
    lib.optionalAttrs isDarwin {
      home = _: { home.packages = [ pkgs.aldente ]; };
    };

  /**
    macOS keyboard-controlled pointer navigation.
  */
  homerow =
    { pkgs, ... }:
    lib.optionalAttrs isDarwin {
      home = _: { home.packages = [ pkgs.homerow ]; };
    };

  /**
    macOS menu bar item management.
  */
  jordanbairdIce =
    { pkgs, ... }:
    lib.optionalAttrs isDarwin {
      home = _: { home.packages = [ pkgs.ice-bar ]; };
    };

  /**
    macOS pointer and scrolling adjustments.
  */
  linearmouse =
    { pkgs, ... }:
    lib.optionalAttrs isDarwin {
      home = _: { home.packages = [ pkgs.linearmouse ]; };
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
