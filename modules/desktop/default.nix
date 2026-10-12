{ lib, system, ... }:

let
  inherit (lib.systems.elaborate system) isLinux;
  linuxOnly =
    scope: lib.setFunctionArgs (args: lib.optionalAttrs isLinux (scope args)) (lib.functionArgs scope);
in
lib.optionalAttrs isLinux {
  # Shared graphical-session infrastructure. Applications, audio, and
  # virtualisation live at the top semantic level instead of under desktop.
  security.polkit.enable = true;
  services.gvfs.enable = true;
  environment.sessionVariables.NIXOS_OZONE_WL = "1";
}
// {
  /**
    Shared X server compatibility support.
  */
  xserver = linuxOnly (import ./xserver);
  /**
    Display-manager policy shared by graphical hosts.
  */
  displayManager = linuxOnly (import ./display-manager);
  /**
    Hyprland desktop session and its host integration.
  */
  hyprland = linuxOnly (import ./hyprland);
  /**
    KDE Plasma desktop session and generated Plasma Manager state.
  */
  plasma = linuxOnly (import ./plasma);

  # Keep GNOME available as an opt-in desktop without changing current hosts.
  /**
    Optional GNOME desktop session.
  */
  gnome = linuxOnly (import ./gnome);
}
// import ./darwin.nix
