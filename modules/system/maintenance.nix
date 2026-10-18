{
  config,
  lib,
  pkgs,
  system,
  ...
}:

let
  inherit (lib.systems.elaborate system) isDarwin isLinux;
  cleanupIntervalDays = 7;
  cleanupStartTime = "03:00";
  retentionDays = 7;

  timeParts = builtins.match "([01][0-9]|2[0-3]):([0-5][0-9])" cleanupStartTime;
  startHour = lib.toInt (lib.removePrefix "0" (builtins.elemAt timeParts 0));
  startMinute = lib.toInt (lib.removePrefix "0" (builtins.elemAt timeParts 1));
  scheduledAt =
    offset:
    let
      minutes = startMinute + offset;
      hour = startHour + builtins.div minutes 60;
      minute = minutes - 60 * builtins.div minutes 60;
    in
    {
      Hour = hour;
      Minute = minute;
    };
  timeString =
    offset:
    let
      time = scheduledAt offset;
      pad = value: lib.fixedWidthString 2 "0" (toString value);
    in
    "${pad time.Hour}:${pad time.Minute}";

  # A seven-day cadence is weekly; other day intervals restart each month.
  calendarDay =
    if cleanupIntervalDays == 7 then "Sun *-*-*" else "*-*-01/${toString cleanupIntervalDays}";
  linuxSchedule = offset: "${calendarDay} ${timeString offset}";
  calendarDays = lib.genList (i: 1 + i * cleanupIntervalDays) (
    1 + builtins.div 30 cleanupIntervalDays
  );
  darwinSchedule =
    offset:
    if cleanupIntervalDays == 7 then
      [ (scheduledAt offset // { Weekday = 7; }) ]
    else
      map (day: scheduledAt offset // { Day = day; }) calendarDays;
  darwinJob =
    name: offset: command:
    pkgs.writeShellScript "maintenance-${name}" ''
      set -euo pipefail
      umask 077
      export PATH=${lib.makeBinPath [ pkgs.coreutils ]}:/usr/bin:/bin
      state=/var/db/.files/maintenance
      mkdir -p "$state"
      exec 9>"$state/lock"
      /usr/bin/lockf -s 9

      # Find the latest scheduled date, even when the Mac missed several days.
      today=$(date +%F)
      if (( $(date +%s) < $(date -d "$today ${timeString offset}" +%s) )); then
        today=$(date -d "$today 1 day ago" +%F)
      fi
      ${
        if cleanupIntervalDays == 7 then
          ''
            weekday=$(date -d "$today" +%w)
            due_day=$(date -d "$today $weekday days ago" +%F)
          ''
        else
          ''
            day=$(date -d "$today" +%-d)
            due_day="''${today:0:8}$(printf '%02d' "$((1 + (day - 1) / ${toString cleanupIntervalDays} * ${toString cleanupIntervalDays}))")"
          ''
      }
      due=$(date -d "$due_day ${timeString offset}" +%s)
      stamp="$state/${name}"
      if [[ -f "$stamp" ]] && read -r last < "$stamp" && [[ $last =~ ^[0-9]+$ ]] && ((last >= due)); then
        exit 0
      fi
      ${lib.escapeShellArgs command}
      printf '%s\n' "$due" > "$stamp"
    '';

in
assert cleanupIntervalDays >= 1 && cleanupIntervalDays <= 31;
assert timeParts != null && startHour * 60 + startMinute + 10 < 1440;
{
  nix.settings.min-free = "2G";

  nix.gc = {
    automatic = true;
    options = "--delete-older-than ${toString retentionDays}d";
  }
  // lib.optionalAttrs isLinux {
    dates = linuxSchedule 0;
    persistent = true;
  }
  // lib.optionalAttrs isDarwin {
    interval = darwinSchedule 0;
  };

  nix.optimise = {
    automatic = true;
  }
  // lib.optionalAttrs isLinux {
    dates = linuxSchedule 5;
    persistent = true;
    randomizedDelaySec = "0";
  }
  // lib.optionalAttrs isDarwin {
    interval = darwinSchedule 5;
  };
}
// lib.optionalAttrs isDarwin {
  launchd.daemons = {
    nix-gc = {
      command = lib.mkForce (
        toString (
          darwinJob "gc" 0 [
            (lib.getExe' config.nix.package "nix-collect-garbage")
            "--delete-older-than"
            "${toString retentionDays}d"
          ]
        )
      );
      serviceConfig.RunAtLoad = lib.mkForce true;
    };
    nix-optimise = {
      command = lib.mkForce (
        toString (
          darwinJob "optimise" 5 [
            (lib.getExe' config.nix.package "nix-store")
            "--optimise"
          ]
        )
      );
      serviceConfig.RunAtLoad = lib.mkForce true;
    };
  };
}
// lib.optionalAttrs isLinux {
  virtualisation.docker.autoPrune = lib.mkIf config.virtualisation.docker.enable {
    enable = true;
    dates = linuxSchedule 10;
    persistent = true;
    flags = [
      "--all"
      "--filter=until=${toString (retentionDays * 24)}h"
    ];
  };
}
// lib.optionalAttrs isLinux {
  services.journald.settings.Journal = {
    SystemMaxUse = "1G";
    SystemKeepFree = config.nix.settings.min-free;
    MaxRetentionSec = "${toString retentionDays}day";
  };
}
