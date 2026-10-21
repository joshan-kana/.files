{ config, pkgs, ... }:

let
  inherit (config.dotfiles) server;
  stateDir = "${server.storage.appData.root}/streamystats";
  credentialsFile = "${server.secretsDir}/streamystats.env";
  webPort = 3013;
in
{
  virtualisation.oci-containers.containers.streamystats = {
    image = "ghcr.io/fredrikburmester/streamystats-aio:latest";
    volumes = [ "${stateDir}:/var/lib/postgresql/data" ];
    ports = [ "${server.lan.serverIp}:${toString webPort}:3000" ];
    environment = {
      POSTGRES_HOST_AUTH_METHOD = "scram-sha-256";
      POSTGRES_INITDB_ARGS = "--auth-host=scram-sha-256";
    };
    environmentFiles = [ credentialsFile ];
    extraOptions = [ "--stop-timeout=60" ];
  };

  systemd = {
    tmpfiles.rules = [
      "d ${stateDir} 0700 root root - -"
    ];

    services = {
      streamystats-credentials = {
        description = "Initialize Streamystats credentials";
        serviceConfig.Type = "oneshot";
        script = ''
          set -eu
          umask 077
          install -d -m 0700 '${server.secretsDir}'
          if [ ! -e '${credentialsFile}' ]; then
            db_password="$(${pkgs.openssl}/bin/openssl rand -hex 24)"
            session_secret="$(${pkgs.openssl}/bin/openssl rand -hex 32)"
            actions_key="$(${pkgs.openssl}/bin/openssl rand -base64 32 | tr -d '\n')"
            file="$(mktemp '${server.secretsDir}/.streamystats.XXXXXXXX')"
            trap 'rm -f "$file"' EXIT
            printf 'POSTGRES_PASSWORD=%s\nSESSION_SECRET=%s\nNEXT_SERVER_ACTIONS_ENCRYPTION_KEY=%s\nDATABASE_URL=postgresql://postgres:%s@localhost:5432/streamystats\n' \
              "$db_password" "$session_secret" "$actions_key" "$db_password" > "$file"
            mv -n "$file" '${credentialsFile}'
          fi
        '';
      };

      docker-streamystats = {
        requires = [ "streamystats-credentials.service" ];
        after = [ "streamystats-credentials.service" ];
        unitConfig.RequiresMountsFor = [ stateDir ];
      };
    };
  };

  virtualisation.vmVariant.dotfiles.scopes.serverApps.streamystats.enable = false;
}
