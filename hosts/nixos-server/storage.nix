{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.dotfiles.server.storage;
  inherit (cfg) appDataRoot dataRoot snapshots;
  pool = cfg.poolName;
  secretsDir = config.dotfiles.server.secretsDir;
  snapshotInterval = "*:0/${toString snapshots.intervalMinutes}";
in
{
  assertions = [
    {
      assertion = snapshots.intervalMinutes <= 60 && lib.mod 60 snapshots.intervalMinutes == 0;
      message = "dotfiles.server.storage.snapshots.intervalMinutes must divide one hour evenly.";
    }
  ];

  users.groups = {
    ${cfg.appDataGroup}.gid = cfg.appDataGroupId;
    ${cfg.group} = { };
  };
  users.users.${config.dotfiles.users.primary.name}.extraGroups = [
    cfg.appDataGroup
    cfg.group
  ];

  environment.systemPackages = with pkgs; [
    restic
    rclone
  ];

  boot.supportedFilesystems = [
    "btrfs"
    "zfs"
  ];
  boot.zfs.extraPools = [ pool ];
  boot.zfs.forceImportRoot = false;

  services.zfs.autoScrub = {
    enable = true;
    pools = [ pool ];
    interval = cfg.scrubInterval;
  };
  services.zfs.trim.enable = false;

  services.sanoid = {
    enable = true;
    interval = snapshotInterval;
    templates.vault = {
      frequent_period = snapshots.intervalMinutes;
      frequently = 60 / snapshots.intervalMinutes;
      inherit (snapshots.retention)
        hourly
        daily
        weekly
        monthly
        ;
      autosnap = true;
      autoprune = true;
    };
    datasets."${pool}/data" = {
      useTemplate = [ "vault" ];
      recursive = "zfs";
    };
  };

  services.snapper = {
    inherit snapshotInterval;
    cleanupInterval = "1h";
    persistentTimer = true;
    configs.apps = {
      SUBVOLUME = appDataRoot;
      FSTYPE = "btrfs";
      TIMELINE_CREATE = true;
      TIMELINE_CLEANUP = true;
      TIMELINE_LIMIT_HOURLY = snapshots.retention.hourly;
      TIMELINE_LIMIT_DAILY = snapshots.retention.daily;
      TIMELINE_LIMIT_WEEKLY = snapshots.retention.weekly;
      TIMELINE_LIMIT_MONTHLY = snapshots.retention.monthly;
    };
  };

  services.restic.backups.apps = {
    initialize = true;
    repository = "rclone:dropbox:Archives/Backups/nixos-server";
    passwordFile = "${secretsDir}/restic-password";
    rcloneConfigFile = "${secretsDir}/rclone.conf";
    paths = [ appDataRoot ];
    exclude = [
      "${appDataRoot}/.snapshots"
      "${appDataRoot}/home-assistant/www/media/ha-bambulab"
    ];
    pruneOpts = [
      "--keep-hourly ${toString snapshots.retention.hourly}"
      "--keep-daily ${toString snapshots.retention.daily}"
      "--keep-weekly ${toString snapshots.retention.weekly}"
      "--keep-monthly ${toString snapshots.retention.monthly}"
    ];
    timerConfig = {
      OnCalendar = "*:0/30";
      Persistent = true;
      RandomizedDelaySec = "5m";
    };
    checkOpts = [ "--read-data-subset=1G" ];
  };

  systemd.tmpfiles.rules = [
    "d ${appDataRoot} 2770 root ${cfg.appDataGroup} - -"
    "v ${appDataRoot}/.snapshots 0750 root root - -"
    "a ${appDataRoot}/.snapshots - - - - u::rwx,g::r-x,o::---,d:u::rwx,d:g::r-x,d:o::---"
  ]
  ++ map (path: "d ${path} 2775 root ${cfg.group} - -") [
    dataRoot
    "${dataRoot}/archive"
    "${dataRoot}/archive/lacie-rescue"
    "${dataRoot}/imports"
    "${dataRoot}/imports/dropbox-test"
    "${dataRoot}/photos"
    "${dataRoot}/media"
    "${dataRoot}/media/library"
    "${dataRoot}/media/downloads"
    "${dataRoot}/media/transcode"
    "${dataRoot}/nextcloud"
    "${dataRoot}/documents"
    "${dataRoot}/shares"
    "${dataRoot}/backups"
  ];
}
