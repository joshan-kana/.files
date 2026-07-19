{
  config,
  pkgs,
  ...
}:

let
  serverCfg = config.dotfiles.server;
  cfg = serverCfg.storage;
  retention = serverCfg.snapshots.retention;
  pool = cfg.poolName;
  inherit (cfg) dataRoot;
in
{
  users.groups.${cfg.group} = { };
  users.users.${config.dotfiles.users.primary.name}.extraGroups = [ cfg.group ];

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
    interval = "hourly";
    templates.vault = {
      inherit (retention)
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

  systemd.tmpfiles.rules = map (path: "d ${path} 2775 root ${cfg.group} - -") [
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

  environment.systemPackages = with pkgs; [
    sanoid
    smartmontools
    zfs
  ];
}
