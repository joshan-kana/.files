{ config, pkgs, ... }:
{
  # Installing Twingate
  services.twingate.enable = true;

  # Performance
  # auto-cpu-freq
  services.auto-cpufreq.enable = true;

  # VMware
  # virtualisation.vmware.host.enable = true;

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
