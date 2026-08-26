_: {
  # Shared graphical-session infrastructure. Applications, audio, and
  # virtualisation live at the top semantic level instead of under desktop.
  security.polkit.enable = true;
  services.gvfs.enable = true;
  environment.sessionVariables.NIXOS_OZONE_WL = "1";

  xserver = import ./xserver.nix;
  displayManager = import ./display-manager;
  hyprland = import ./hyprland;
  plasma = import ./plasma;

  # Keep GNOME available as an opt-in desktop without changing current hosts.
  gnome = import ./gnome;
}
