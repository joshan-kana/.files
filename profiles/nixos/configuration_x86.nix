{ config, pkgs, ... }:
{
  # Installing Twingate
  services.twingate.enable = true;

  # VMware
  # virtualisation.vmware.host.enable = true;

  environment.systemPackages = with pkgs; [
    brave
    spotify
    nvtopPackages.full
    intel-gpu-tools
    bitwarden-desktop
    discord
    dropbox
    warp-terminal
    onlyoffice-desktopeditors
  ];
}
