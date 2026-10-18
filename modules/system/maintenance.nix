{
  config,
  lib,
  options,
  system,
  ...
}:

let
  inherit (lib.systems.elaborate system) isDarwin isLinux;
  cleanupIntervalDays = 7;
  retentionDays = 7;
  # Native stepped day-of-month schedules restart at each month boundary.
  # The seven-day default uses a true weekly calendar schedule instead.
  schedule = if cleanupIntervalDays == 7 then "weekly" else "*-*-01/${toString cleanupIntervalDays}";
  calendarDays = lib.genList (i: 1 + i * cleanupIntervalDays) (
    1 + builtins.div 30 cleanupIntervalDays
  );
  darwinInterval =
    option:
    if cleanupIntervalDays == 7 then
      option.default
    else
      map (
        day: (builtins.removeAttrs (builtins.head option.default) [ "Weekday" ]) // { Day = day; }
      ) calendarDays;
in
assert cleanupIntervalDays >= 1 && cleanupIntervalDays <= 31;
{
  nix.settings.min-free = "2G";

  nix.gc = {
    automatic = true;
    options = "--delete-older-than ${toString retentionDays}d";
  }
  // lib.optionalAttrs isLinux {
    dates =
      if cleanupIntervalDays == 7 then
        schedule
      else
        "${schedule} ${builtins.head options.nix.gc.dates.default}";
  }
  // lib.optionalAttrs isDarwin {
    interval = darwinInterval options.nix.gc.interval;
  };

  nix.optimise = {
    automatic = true;
  }
  // lib.optionalAttrs isLinux {
    dates =
      if cleanupIntervalDays == 7 then
        schedule
      else
        "${schedule} ${builtins.head options.nix.optimise.dates.default}";
  }
  // lib.optionalAttrs isDarwin {
    interval = darwinInterval options.nix.optimise.interval;
  };
}
// lib.optionalAttrs isLinux {
  virtualisation.docker.autoPrune = lib.mkIf config.virtualisation.docker.enable {
    enable = true;
    dates = schedule;
    flags = [
      "--all"
      "--filter=until=${toString (retentionDays * 24)}h"
    ];
  };
}
// lib.optionalAttrs (isLinux && options.services.journald ? settings) {
  services.journald.settings.Journal = {
    SystemMaxUse = "1G";
    SystemKeepFree = config.nix.settings.min-free;
    MaxRetentionSec = "${toString retentionDays}day";
  };
}
