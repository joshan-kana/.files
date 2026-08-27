{
  system = import ./system;
  nix = import ./nix;
  theme = import ./theme;
  cli = import ./cli;
  networking = import ./networking;
  appimage = import ./appimage;
  audio = import ./audio;
  virtualisation = import ./virtualisation;
  desktop = import ./desktop;
  desktopApps = import ./desktop-apps;
  serverApps = import ./server-apps;

  profiles = import ./profiles;
}
