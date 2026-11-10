{ lib, system, ... }:

let
  inherit (lib.systems.elaborate system) isDarwin isLinux;
in
lib.optionalAttrs isLinux {
  # Shared graphical-session infrastructure. Applications, audio, and
  # virtualisation live at the top semantic level instead of under desktop.
  services.gvfs.enable = true;
  environment.sessionVariables.NIXOS_OZONE_WL = "1";

  /**
    Shared X server compatibility support.
  */
  xserver = import ./xserver;
  /**
    Display-manager policy shared by graphical hosts.
  */
  displayManager = import ./display-manager;
  /**
    Hyprland desktop session and its host integration.
  */
  hyprland = import ./hyprland;
  /**
    KDE Plasma desktop session and generated Plasma Manager state.
  */
  plasma = import ./plasma;

  # Keep GNOME available as an opt-in desktop without changing current hosts.
  /**
    Optional GNOME desktop session.
  */
  gnome = import ./gnome;
}
// {
  karabinerElements = _: lib.optionalAttrs isDarwin ((import ./karabiner) { });

  hammerspoon =
    { lib, pkgs, ... }: lib.optionalAttrs isDarwin ((import ./hammerspoon) { inherit lib pkgs; });

  raycast =
    { pkgs, ... }:
    lib.optionalAttrs isDarwin {
      home = _: { home.packages = [ pkgs.raycast ]; };
    };

  yabai = { lib, system, ... }: lib.optionalAttrs isDarwin ((import ./yabai) { inherit lib system; });

  aldente =
    { pkgs, ... }:
    lib.optionalAttrs isDarwin {
      home = _: { home.packages = [ pkgs.aldente ]; };
    };

  homerow =
    { pkgs, ... }:
    lib.optionalAttrs isDarwin {
      home = _: { home.packages = [ pkgs.homerow ]; };
    };

  jordanbairdIce =
    { pkgs, ... }:
    lib.optionalAttrs isDarwin {
      home = _: { home.packages = [ pkgs.ice-bar ]; };
    };

  linearmouse =
    { pkgs, ... }:
    lib.optionalAttrs isDarwin {
      home = _: { home.packages = [ pkgs.linearmouse ]; };
    };

  logiOptions =
    _:
    lib.optionalAttrs isDarwin {
      homebrew.casks = [ "logi-options+" ];
    };
}
