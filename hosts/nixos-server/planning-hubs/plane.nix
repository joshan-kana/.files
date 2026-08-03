{
  config,
  lib,
  ...
}:

let
  serverCfg = config.dotfiles.server;
  appDataRoot = serverCfg.storage.appData.root;
  inherit (serverCfg) secretsDir;

  planeDataRoot = "${appDataRoot}/plane";
in
{
  # Plane Community Edition trial: https://developers.plane.so/self-hosting
  #
  # Uses the single-container All-In-One image, which packages web, space,
  # admin, api, live, worker, beat, migrator and the Caddy proxy into one
  # container. This is the lightest Plane deployment shape and is intended
  # for testing / small deployments, which fits a Raspberry Pi 4 trial.
  #
  # Resources: min 2 CPU / 4 GB RAM (8 GB recommended). The Pi 4 has 8 GB RAM
  # but already hosts Home Assistant, OpenClaw, n8n, AdGuard, etc. Start with
  # Plane alone during the trial and observe memory before stacking services.
  virtualisation.oci-containers.containers.plane = {
    image = "makeplane/plane-aio-community:latest";
    pull = serverCfg.containers.pullPolicy;

    # LAN-only access on a dedicated host port. No public exposure.
    # 8080 is unused by existing server services (53, 8123, 5678, 5580, 18789).
    ports = [ "8080:80" ];

    volumes = [
      "${planeDataRoot}/logs:/app/logs"
      "${planeDataRoot}/data:/app/data"
    ];

    environmentFiles = [ "${secretsDir}/plane.env" ];
  };

  systemd.services.docker-plane.restartTriggers = [ serverCfg.containers.restartTrigger ];

  # Persist app data under the existing app data model, owned by the editor group.
  systemd.tmpfiles.rules = [
    "d ${planeDataRoot} 0755 root ${serverCfg.storage.appData.group.name} - -"
    "d ${planeDataRoot}/logs 0755 root ${serverCfg.storage.appData.group.name} - -"
    "d ${planeDataRoot}/data 0755 root ${serverCfg.storage.appData.group.name} - -"
  ];

  # LAN access only; allow HTTP on the dedicated Plane port.
  networking.firewall.allowedTCPPorts = lib.mkAfter [ 8080 ];

  # Guard the module: the secrets/env file must exist before the container can start.
  systemd.services.docker-plane.unitConfig.AssertPathExists = [
    "${secretsDir}/plane.env"
  ];

  # Documented requirements for a functional trial. Kept declarative here so
  # the env file (which holds credentials) stays out of the repo.
  #   DOMAIN_NAME=192.168.1.3
  #   WEB_URL=http://192.168.1.3:8080
  #   SITE_ADDRESS=192.168.1.3:80
  #   CORS_ALLOWED_ORIGINS=http://192.168.1.3:8080
  #   DATABASE_URL=postgresql://plane:plane@<host>:<port>/plane
  #   REDIS_URL=redis://<host>:<port>
  #   AMQP_URL=amqp://plane:plane@<host>:<port>/plane
  #   AWS_REGION=us-east-1
  #   AWS_ACCESS_KEY_ID=...
  #   AWS_SECRET_ACCESS_KEY=...
  #   AWS_S3_BUCKET_NAME=uploads
  #   AWS_S3_ENDPOINT_URL=http://<host>:<port>
  #   SECRET_KEY=...
  #   LIVE_SERVER_SECRET_KEY=...
  #
  # The AIO image bundles Postgres/Redis/RabbitMQ/MinIO; external services are
  # recommended for production but local bundled storage is fine for the trial.
  # Access the instance admin at http://192.168.1.3:8080/god-mode to register.
}
