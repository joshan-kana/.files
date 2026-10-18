{
  config,
  lib,
  options,
  system,
  ...
}:

let
  inherit (lib.systems.elaborate system) isLinux;
  cleanupRetentionDays = 7;
  cleanupSchedule = "weekly";
in
lib.optionalAttrs isLinux {
  nix.gc = {
    automatic = true;
    dates = cleanupSchedule;
    options = "--delete-older-than ${toString cleanupRetentionDays}d";
  };

  nix.optimise = {
    automatic = true;
    dates = [ cleanupSchedule ];
  };

  services.journald =
    if options.services.journald ? settings then
      {
        settings.Journal = {
          SystemMaxUse = "1G";
          SystemKeepFree = config.nix.settings.min-free;
          MaxRetentionSec = "${toString cleanupRetentionDays}day";
        };
      }
    else
      {
        extraConfig = ''
          SystemMaxUse=1G
          SystemKeepFree=${config.nix.settings.min-free}
          MaxRetentionSec=${toString cleanupRetentionDays}day
        '';
      };

  virtualisation.docker.autoPrune = lib.mkIf config.virtualisation.docker.enable {
    enable = true;
    dates = cleanupSchedule;
    flags = [
      "--all"
      "--filter=until=${toString (cleanupRetentionDays * 24)}h"
    ];
  };
}
