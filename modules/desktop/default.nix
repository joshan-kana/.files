{ lib, system, ... }:

let
  inherit (lib.systems.elaborate system) isLinux;
in
lib.optionalAttrs isLinux {
  # Shared graphical-session infrastructure. Applications, audio, and
  # virtualisation live at the top semantic level instead of under desktop.
  security.polkit.enable = true;
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
