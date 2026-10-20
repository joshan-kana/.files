{ config, pkgs, ... }:

let
  inherit (config.dotfiles) server;
  inherit (server.storage) appData dataRoot;
  mediaRoot = "${dataRoot.path}/media";
  transmissionCredentials = "${server.secretsDir}/transmission.json";
in
{
  services.transmission = {
    enable = true;
    package = pkgs.transmission_4;
    home = "${appData.root}/transmission";
    group = dataRoot.group.name;
    credentialsFile = transmissionCredentials;
    downloadDirPermissions = "2770";
    settings = {
      download-dir = "${mediaRoot}/downloads/complete";
      incomplete-dir = "${mediaRoot}/downloads/incomplete";
      rpc-bind-address = "0.0.0.0";
      rpc-authentication-required = true;
      rpc-whitelist-enabled = false;
      rpc-host-whitelist-enabled = false;
      umask = "002";
    };
  };

  users.users.${config.services.transmission.user}.extraGroups = [
    appData.group.name
    dataRoot.group.name
  ];

  systemd.services = {
    transmission = {
      unitConfig.RequiresMountsFor = [ mediaRoot ];
      requires = [
        "transmission-setup.service"
        "transmission-credentials.service"
      ];
      after = [
        "transmission-setup.service"
        "transmission-credentials.service"
      ];
    };
    transmission-setup.unitConfig.RequiresMountsFor = [ mediaRoot ];
    transmission-credentials = {
      description = "Initialize Transmission RPC credentials";
      serviceConfig.Type = "oneshot";
      script = ''
        set -eu
        umask 077
        install -d -m 0700 '${server.secretsDir}'
        if [ ! -e '${transmissionCredentials}' ]; then
          password="$(${pkgs.openssl}/bin/openssl rand -hex 32)"
          file="$(mktemp '${server.secretsDir}/.transmission.XXXXXXXX')"
          trap 'rm -f "$file"' EXIT
          printf '{"rpc-username":"media","rpc-password":"%s"}\n' "$password" > "$file"
          mv -n "$file" '${transmissionCredentials}'
        fi
      '';
    };
  };

  networking.firewall.interfaces.${server.lan.interface}.allowedTCPPorts = [
    config.services.transmission.settings.rpc-port
  ];
}
