_: {
  xserver = import ./xserver.nix;
  session = import ./session.nix;
  integration = import ./integration.nix;
  virtualisation = import ./virtualisation.nix;
  audio = import ./audio.nix;
  browsers = import ./browsers.nix;
  terminals = import ./terminals.nix;
  apps = import ./apps.nix;
  media = import ./media.nix;
  ollama = import ./ollama.nix;

  displayManager = import ../../desktop/display-manager.nix;
  hyprland = import ../../desktop/hyprland;
  plasma = import ../../desktop/plasma;
}
