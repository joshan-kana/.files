{ config, pkgs, ... }:
{
  # Installing Twingate
  services.twingate.enable = true;

  # VMware
  virtualisation.vmware.host.enable = true;

  # Bootloader
  boot.loader.systemd-boot.enable = true;

  environment.systemPackages = with pkgs; [
    brave
    spotify
    nvtop
    intel-gpu-tools
    bitwarden
    discord
    dropbox
    warp-terminal
    onlyoffice-bin
  ];
}
