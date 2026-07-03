_: {
  # Enable Hyprland at the NixOS (system) level so display managers (e.g. `ly`)
  # can discover the Wayland session entry.
  programs.hyprland = {
    enable = true;
    xwayland.enable = true;
  };
}
