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
    # mautrix-discord still requires deprecated libolm; the other bridges use goolm.
    config.permittedInsecurePackages = [ "olm-3.2.16" ];
  };
  mautrixPkgs = inputs.mautrix-packages.packages.${system};

  bridgeManager = unstablePkgs.beeper-bridge-manager;
  meta = unstablePkgs.mautrix-meta.override { withGoolm = true; };

  bridges = {
    whatsapp = unstablePkgs.mautrix-whatsapp.override { withGoolm = true; };
    signal = unstablePkgs.mautrix-signal.override { withGoolm = true; };
    discord = unstablePkgs.mautrix-discord;
    facebook = meta;
    instagram = meta;
    telegram = mautrixPkgs.mautrix-telegram.override { withGoOlm = true; };
  };

  bridgeBinaries = {
    whatsapp = "${bridges.whatsapp}/bin/mautrix-whatsapp";
    signal = "${bridges.signal}/bin/mautrix-signal";
    discord = "${bridges.discord}/bin/mautrix-discord";
    facebook = "${bridges.facebook}/bin/mautrix-meta";
    instagram = "${bridges.instagram}/bin/mautrix-instagram";
    telegram = "${bridges.telegram}/bin/mautrix-telegram";
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
        login|login-password|logout)
          umask 077
          exec ${pkgs.coreutils}/bin/env \
            HOME=${stateRoot} \
            XDG_DATA_HOME=${dataRoot} \
            BEEPER_ENV=prod \
            ${bridgeManager}/bin/bbctl --config ${bbctlSecret} "$@"
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
    ];

    systemd.services."matrix-bridge-${provider}" = {
      description = "Beeper self-hosted ${provider} Matrix bridge";
      wantedBy = [ "multi-user.target" ];
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
  nix.settings = {
    substituters = [ "https://moraxyc.cachix.org" ];
    trusted-public-keys = [
      "moraxyc.cachix.org-1:p00BlzhjSZq23aXYuzeUF2uXdE8ikh6tq9aV1seenhQ="
    ];
  };

  users.groups.${bridgeUser} = { };
  users.users.${bridgeUser} = {
    isSystemUser = true;
    group = bridgeUser;
    extraGroups = [ appDataGroup ];
    home = stateRoot;
  };

  systemd.tmpfiles.rules = [
    "d ${stateRoot} 2750 ${bridgeUser} ${appDataGroup} -"
    "d ${dataRoot} 2750 ${bridgeUser} ${appDataGroup} -"
    "d ${dataRoot}/bbctl 2750 ${bridgeUser} ${appDataGroup} -"
    "d ${bridgeDataRoot} 2750 ${bridgeUser} ${appDataGroup} -"
  ];

  environment.systemPackages = [ bbctl ];

  whatsapp = mkBridge "whatsapp" bridgeBinaries.whatsapp;
  signal = mkBridge "signal" bridgeBinaries.signal;
  discord = mkBridge "discord" bridgeBinaries.discord;
  instagram = mkBridge "instagram" bridgeBinaries.instagram;
  facebook = mkBridge "facebook" bridgeBinaries.facebook;
  telegram = mkBridge "telegram" bridgeBinaries.telegram;
}
