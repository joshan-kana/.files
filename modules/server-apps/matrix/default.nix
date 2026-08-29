{
  config,
  inputs,
  pkgs,
  ...
}:

let
  appDataRoot = config.dotfiles.server.storage.appData.root;
  appDataGroup = config.dotfiles.server.storage.appData.group.name;

  bridgeUser = "matrix-bridge";
  stateRoot = "${appDataRoot}/matrix";
  dataRoot = "${stateRoot}/data";
  bbctlConfig = "${stateRoot}/config/bbctl.json";
  bridgeDataRoot = "${dataRoot}/bbctl/prod";

  bridgeManager = inputs.nixpkgs.legacyPackages.${pkgs.stdenv.hostPlatform.system}.beeper-bridge-manager;

  bbctl = pkgs.writeShellApplication {
    name = "bbctl";
    text = ''
      if [ "$(${pkgs.coreutils}/bin/id -u)" -ne 0 ]; then
        exec /run/wrappers/bin/sudo "$0" "$@"
      fi

      exec ${pkgs.util-linux}/bin/runuser -u ${bridgeUser} -- \
        ${pkgs.coreutils}/bin/env \
          HOME=${stateRoot} \
          XDG_DATA_HOME=${dataRoot} \
          BBCTL_CONFIG=${bbctlConfig} \
          BEEPER_ENV=prod \
          ${bridgeManager}/bin/bbctl "$@"
    '';
  };

  mkBridge = provider: _: {
    systemd.tmpfiles.rules = [
      "d ${bridgeDataRoot}/sh-${provider} 2750 ${bridgeUser} ${appDataGroup} -"
    ];

    systemd.services."matrix-bridge-${provider}" = {
      description = "Beeper self-hosted ${provider} Matrix bridge";
      wantedBy = [ "multi-user.target" ];
      wants = [ "network-online.target" ];
      after = [ "network-online.target" ];
      unitConfig.ConditionPathExists = bbctlConfig;

      environment = {
        HOME = stateRoot;
        XDG_DATA_HOME = dataRoot;
        BBCTL_CONFIG = bbctlConfig;
        BEEPER_ENV = "prod";
      };

      path = [ pkgs.ffmpeg-headless ];

      serviceConfig = {
        User = bridgeUser;
        Group = bridgeUser;
        WorkingDirectory = stateRoot;
        ExecStart = "${bridgeManager}/bin/bbctl run --no-update --no-override-config sh-${provider}";
        Restart = "always";
        RestartSec = "10s";
        UMask = "0077";

        NoNewPrivileges = true;
        PrivateTmp = true;
        ProtectHome = true;
        ProtectSystem = "strict";
        ReadWritePaths = [ stateRoot ];
      };
    };
  };
in
{
  users.groups.${bridgeUser} = { };
  users.users.${bridgeUser} = {
    isSystemUser = true;
    group = bridgeUser;
    extraGroups = [ appDataGroup ];
    home = stateRoot;
  };

  systemd.tmpfiles.rules = [
    "d ${stateRoot} 2750 ${bridgeUser} ${appDataGroup} -"
    "d ${stateRoot}/config 0700 ${bridgeUser} ${bridgeUser} -"
    "d ${dataRoot} 2750 ${bridgeUser} ${appDataGroup} -"
    "d ${dataRoot}/bbctl 2750 ${bridgeUser} ${appDataGroup} -"
    "d ${bridgeDataRoot} 2750 ${bridgeUser} ${appDataGroup} -"
  ];

  environment.systemPackages = [ bbctl ];

  whatsapp = mkBridge "whatsapp";
  signal = mkBridge "signal";
  discord = mkBridge "discord";
  instagram = mkBridge "instagram";
  facebook = mkBridge "facebook";
  telegram = mkBridge "telegram";
}
