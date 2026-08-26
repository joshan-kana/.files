{ pkgs, ... }:

{
  # Retained for the desktop applications which currently require it.
  nixpkgs.config.permittedInsecurePackages = [ "electron-39.8.10" ];

  thunderbird = _: {
    environment.systemPackages = [ pkgs.thunderbird ];
  };
  obsidian = _: {
    environment.systemPackages = [ pkgs.obsidian ];
  };
  filelight = _: {
    environment.systemPackages = [ pkgs.kdePackages.filelight ];
  };
  gimp = _: {
    environment.systemPackages = [ pkgs.gimp ];
  };
  gparted = _: {
    environment.systemPackages = [ pkgs.gparted ];
  };
  githubDesktop = _: {
    environment.systemPackages = [ pkgs.github-desktop ];
  };
  nautilus = _: {
    environment.systemPackages = [ pkgs.nautilus ];
  };
  vscode = _: {
    home = _: {
      programs.vscode = { };
    };
  };
  pycharm = _: {
    environment.systemPackages = [ pkgs.jetbrains.pycharm ];
  };
  libreoffice = _: {
    environment.systemPackages = [ pkgs.libreoffice ];
  };
}
