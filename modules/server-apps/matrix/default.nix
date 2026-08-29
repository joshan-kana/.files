{
  config,
  inputs,
  pkgs,
  ...
}:

let
  serverCfg = config.dotfiles.server;
  appDataRoot = serverCfg.storage.appData.root;
  appDataGroup = serverCfg.storage.appData.group.name;

  bridgeUser = "matrix-bridge";
  stateRoot = "${appDataRoot}/matrix";
  dataRoot = "${stateRoot}/data";
  bridgeDataRoot = "${dataRoot}/bbctl/prod";
  bbctlSecret = "${serverCfg.secretsDir}/beeper-bbctl.json";

  system = pkgs.stdenv.hostPlatform.system;
  unstablePkgs = import inputs.nixpkgs {
    inherit system;
    # Current cached mautrix packages still depend on deprecated libolm.
    config.permittedInsecurePackages = [ "olm-3.2.16" ];
  };
  mautrixPkgs = inputs.mautrix-packages.packages.${system};

  bridgeManager = unstablePkgs.beeper-bridge-manager;

  bridges = {
    whatsapp = "${unstablePkgs.mautrix-whatsapp}/bin/mautrix-whatsapp";
    signal = "${unstablePkgs.mautrix-signal}/bin/mautrix-signal";
    discord = "${unstablePkgs.mautrix-discord}/bin/mautrix-discord";
    facebook = "${unstablePkgs.mautrix-meta}/bin/mautrix-meta";
    instagram = "${unstablePkgs.mautrix-meta}/bin/mautrix-instagram";
    telegram = "${mautrixPkgs.mautrix-telegram}/bin/mautrix-telegram";
  };

  bbctlCredentialRunner = pkgs.writeShellScript "bbctl-credential-runner" ''
    export HOME=${stateRoot}
    export XDG_DATA_HOME=${dataRoot}
    export BEEPER_ENV=prod
    exec ${bridgeManager}/bin/bbctl --config "$CREDENTIALS_DIRECTORY/bbctl.json" "$@"
  '';

  bbctl = pkgs.writeShellApplication {
    name = "bbctl";
    text = ''
      if [ "$(${pkgs.coreutils}/bin/id -u)" -ne 0 ]; then
        exec /run/wrappers/bin/sudo "$0" "$@"
      fi

      case "''${1:-}" in
        login|login-password)
          umask 077
          ${pkgs.coreutils}/bin/env \
            HOME=${stateRoot} \
            XDG_DATA_HOME=${dataRoot} \
            BEEPER_ENV=prod \
            ${bridgeManager}/bin/bbctl --config ${bbctlSecret} "$@"
          exec ${pkgs.systemd}/bin/systemctl restart matrix-bridges.target
          ;;
        logout)
          umask 077
          ${pkgs.coreutils}/bin/env \
            HOME=${stateRoot} \
            XDG_DATA_HOME=${dataRoot} \
            BEEPER_ENV=prod \
            ${bridgeManager}/bin/bbctl --config ${bbctlSecret} "$@"
          exec ${pkgs.systemd}/bin/systemctl stop matrix-bridges.target
          ;;
      esac

      exec ${pkgs.systemd}/bin/systemd-run \
        --quiet \
        --pipe \
        --wait \
        --collect \
        --property=User=${bridgeUser} \
        --property=Group=${bridgeUser} \
        --property=WorkingDirectory=${stateRoot} \
        --property=LoadCredential=bbctl.json:${bbctlSecret} \
        ${bbctlCredentialRunner} "$@"
    '';
  };

  mkBridge = provider: binary: _: {
    systemd.tmpfiles.rules = [
      "d ${bridgeDataRoot}/sh-${provider} 2750 ${bridgeUser} ${appDataGroup} -"
      "z ${bridgeDataRoot}/sh-${provider}/*.db* 0600 ${bridgeUser} ${appDataGroup} -"
    ];

    systemd.services."matrix-bridge-${provider}" = {
      description = "Beeper self-hosted ${provider} Matrix bridge";
      wantedBy = [ "matrix-bridges.target" ];
      partOf = [ "matrix-bridges.target" ];
      wants = [ "network-online.target" ];
      after = [ "network-online.target" ];
      unitConfig.ConditionPathExists = bbctlSecret;

      environment = {
        HOME = stateRoot;
        XDG_DATA_HOME = dataRoot;
        BEEPER_ENV = "prod";
      };

      path = [ pkgs.ffmpeg-headless ];

      serviceConfig = {
        User = bridgeUser;
        Group = bridgeUser;
        WorkingDirectory = stateRoot;
        LoadCredential = [ "bbctl.json:${bbctlSecret}" ];
        ExecCondition = "${bbctlCredentialRunner} whoami";
        ExecStart = "${bridgeManager}/bin/bbctl --config %d/bbctl.json run --no-override-config --custom-startup-command ${binary} sh-${provider}";
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

  systemd.targets."matrix-bridges" = {
    description = "Beeper self-hosted Matrix bridges";
    wantedBy = [ "multi-user.target" ];
  };

  systemd.tmpfiles.rules = [
    "d ${stateRoot} 2750 ${bridgeUser} ${appDataGroup} -"
    "d ${dataRoot} 2750 ${bridgeUser} ${appDataGroup} -"
    "d ${dataRoot}/bbctl 2750 ${bridgeUser} ${appDataGroup} -"
    "d ${bridgeDataRoot} 2750 ${bridgeUser} ${appDataGroup} -"
  ];

  environment.systemPackages = [ bbctl ];

  whatsapp = mkBridge "whatsapp" bridges.whatsapp;
  signal = mkBridge "signal" bridges.signal;
  discord = mkBridge "discord" bridges.discord;
  instagram = mkBridge "instagram" bridges.instagram;
  facebook = mkBridge "facebook" bridges.facebook;
  telegram = mkBridge "telegram" bridges.telegram;
}
