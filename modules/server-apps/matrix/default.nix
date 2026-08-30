{
  config,
  inputs,
  pkgs,
  ...
}:

let
  inherit (config.dotfiles) server;
  inherit (server.storage) appData;

  bridgeUser = "matrix-bridge";
  stateRoot = "${appData.root}/matrix";
  dataRoot = "${stateRoot}/data";
  bridgeDataRoot = "${dataRoot}/bbctl/prod";
  bbctlSecretFile = "${server.secretsDir}/beeper-bbctl-secret.json";

  inherit (pkgs.stdenv.hostPlatform) system;
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
            ${bridgeManager}/bin/bbctl --config ${bbctlSecretFile} "$@"
          exec ${pkgs.systemd}/bin/systemctl restart matrix-bridges.target
          ;;
        logout)
          umask 077
          ${pkgs.coreutils}/bin/env \
            HOME=${stateRoot} \
            XDG_DATA_HOME=${dataRoot} \
            BEEPER_ENV=prod \
            ${bridgeManager}/bin/bbctl --config ${bbctlSecretFile} "$@"
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
        --property=LoadCredential=bbctl.json:${bbctlSecretFile} \
        ${bbctlCredentialRunner} "$@"
    '';
  };

  mkBridge = provider: binary: _: {
    systemd.tmpfiles.rules = [
      "d ${bridgeDataRoot}/sh-${provider} 2750 ${bridgeUser} ${appData.group.name} -"
      "z ${bridgeDataRoot}/sh-${provider}/*.db* 0600 ${bridgeUser} ${appData.group.name} -"
    ];

    systemd.services."matrix-bridge-${provider}" = {
      description = "Beeper self-hosted ${provider} Matrix bridge";
      wantedBy = [ "matrix-bridges.target" ];
      partOf = [ "matrix-bridges.target" ];
      wants = [ "network-online.target" ];
      after = [ "network-online.target" ];
      unitConfig.AssertPathExists = bbctlSecretFile;

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
        LoadCredential = [ "bbctl.json:${bbctlSecretFile}" ];
        ExecCondition = "${pkgs.jq}/bin/jq -e '(.environments.prod.access_token? // \"\") | startswith(\"syt_\") or startswith(\"bat_\")' %d/bbctl.json";
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
    extraGroups = [ appData.group.name ];
    home = stateRoot;
  };

  systemd.targets."matrix-bridges" = {
    description = "Beeper self-hosted Matrix bridges";
    wantedBy = [ "multi-user.target" ];
  };

  systemd.tmpfiles.rules = [
    "d ${stateRoot} 2750 ${bridgeUser} ${appData.group.name} -"
    "d ${dataRoot} 2750 ${bridgeUser} ${appData.group.name} -"
    "d ${dataRoot}/bbctl 2750 ${bridgeUser} ${appData.group.name} -"
    "d ${bridgeDataRoot} 2750 ${bridgeUser} ${appData.group.name} -"
  ];

  environment.systemPackages = [ bbctl ];

  whatsapp = mkBridge "whatsapp" bridges.whatsapp;
  signal = mkBridge "signal" bridges.signal;
  discord = mkBridge "discord" bridges.discord;
  instagram = mkBridge "instagram" bridges.instagram;
  facebook = mkBridge "facebook" bridges.facebook;
  telegram = mkBridge "telegram" bridges.telegram;
}
