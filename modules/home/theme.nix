{ config, ... }:

{
  # Shared Home Manager Stylix defaults moved from the old main-branch home.nix.
  # Keep these global unless the repo policy changes.
  stylix.targets.qt.platform = "kde";
  stylix.targets.vscode.enable = false;

  # This existed in the old Home Manager config and is kept here so theming
  # behaviour stays the same after the modular refactor.
  gtk.gtk4.theme = config.gtk.theme;
}
