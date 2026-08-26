{ pkgs, ... }:

let
  cleanupRetentionDays = 7;
  cleanupSchedule = "weekly";
  minFree = "2G";
in
{
  nix.gc = {
    automatic = true;
    dates = cleanupSchedule;
    options = "--delete-older-than ${toString cleanupRetentionDays}d";
  };

  nix.optimise = {
    automatic = true;
    dates = [ cleanupSchedule ];
  };

  nix.settings = {
    min-free = minFree;
    substituters = [ "https://nixos-raspberrypi.cachix.org" ];
    trusted-public-keys = [
      "nixos-raspberrypi.cachix.org-1:4iMO9LXa8BqhU+Rpg6LQKiGa2lsNh/j2oiYLNOQ5sPI="
    ];
  };

  services.journald.extraConfig = ''
    SystemMaxUse=1G
    SystemKeepFree=${minFree}
    MaxRetentionSec=${toString cleanupRetentionDays}day
  '';

  virtualisation.docker.autoPrune = {
    enable = true;
    dates = cleanupSchedule;
    flags = [
      "--all"
      "--filter=until=${toString (cleanupRetentionDays * 24)}h"
    ];
  };

  environment.systemPackages = with pkgs; [
    curl
    jq
    rsync
  ];
}
