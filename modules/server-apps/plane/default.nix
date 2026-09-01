{
  config,
  lib,
  ...
}:

let
  inherit (config.dotfiles) server;
  inherit (server.storage) appData;

  hostPort = 8090;
  planeDataRoot = "${appData.root}/plane";
  planeSecret = "${server.secretsDir}/plane.env";
  planeNetwork = "plane";
  planeTag = "stable";
  planeUrl = "http://${server.lan.serverIp}:${toString hostPort}";

  data = name: "${planeDataRoot}/${name}";
  networkOptions =
    alias: [ "--network=${planeNetwork}" ] ++ lib.optional (alias != null) "--network-alias=${alias}";

  dbEnv = {
    PGHOST = "plane-db";
    PGDATABASE = "plane";
    POSTGRES_USER = "plane";
    POSTGRES_DB = "plane";
    POSTGRES_PORT = "5432";
    PGDATA = "/var/lib/postgresql/data";
  };
  redisEnv = {
    REDIS_HOST = "plane-redis";
    REDIS_PORT = "6379";
    REDIS_URL = "redis://plane-redis:6379/";
  };
  mqEnv = {
    RABBITMQ_HOST = "plane-mq";
    RABBITMQ_PORT = "5672";
    RABBITMQ_DEFAULT_USER = "plane";
    RABBITMQ_DEFAULT_VHOST = "plane";
    RABBITMQ_VHOST = "plane";
  };
  s3Env = {
    AWS_S3_ENDPOINT_URL = "http://plane-minio:9000";
    AWS_S3_BUCKET_NAME = "uploads";
  };
  appEnv = {
    WEB_URL = planeUrl;
    CORS_ALLOWED_ORIGINS = planeUrl;
    DEBUG = "0";
    GUNICORN_WORKERS = "1";
    USE_MINIO = "1";
    API_KEY_RATE_LIMIT = "60/minute";
    MINIO_ENDPOINT_SSL = "0";
    WEBHOOK_ALLOWED_IPS = "";
    WEBHOOK_ALLOWED_HOSTS = "";
  };
  proxyEnv = {
    APP_DOMAIN = "${server.lan.serverIp}:${toString hostPort}";
    FILE_SIZE_LIMIT = "5242880";
    LISTEN_HTTP_PORT = "80";
    LISTEN_HTTPS_PORT = "443";
    BUCKET_NAME = "uploads";
    SITE_ADDRESS = ":80";
    CERT_EMAIL = "";
    CERT_ACME_CA = "https://acme-v02.api.letsencrypt.org/directory";
    CERT_ACME_DNS = "";
  };

  backend = {
    image = "makeplane/plane-backend:${planeTag}";
    environment = appEnv // dbEnv // redisEnv // s3Env // proxyEnv;
    environmentFiles = [ planeSecret ];
  };

  planeContainers = {
    plane-web = {
      image = "makeplane/plane-frontend:${planeTag}";
      dependsOn = [
        "plane-api"
        "plane-worker"
      ];
      extraOptions = networkOptions "web";
    };

    plane-space = {
      image = "makeplane/plane-space:${planeTag}";
      dependsOn = [
        "plane-api"
        "plane-worker"
        "plane-web"
      ];
      extraOptions = networkOptions "space";
    };

    plane-admin = {
      image = "makeplane/plane-admin:${planeTag}";
      dependsOn = [
        "plane-api"
        "plane-web"
      ];
      extraOptions = networkOptions "admin";
    };

    plane-live = {
      image = "makeplane/plane-live:${planeTag}";
      dependsOn = [
        "plane-api"
        "plane-web"
      ];
      environment = redisEnv // {
        API_BASE_URL = "http://api:8000";
      };
      environmentFiles = [ planeSecret ];
      extraOptions = networkOptions "live";
    };

    plane-api = backend // {
      cmd = [ "./bin/docker-entrypoint-api.sh" ];
      dependsOn = [
        "plane-db"
        "plane-redis"
        "plane-mq"
      ];
      extraOptions = networkOptions "api";
      volumes = [ "${data "logs-api"}:/code/plane/logs" ];
    };

    plane-worker = backend // {
      cmd = [ "./bin/docker-entrypoint-worker.sh" ];
      dependsOn = [
        "plane-api"
        "plane-db"
        "plane-redis"
        "plane-mq"
      ];
      extraOptions = networkOptions "worker";
      volumes = [ "${data "logs-worker"}:/code/plane/logs" ];
    };

    plane-beat-worker = backend // {
      cmd = [ "./bin/docker-entrypoint-beat.sh" ];
      dependsOn = [
        "plane-api"
        "plane-db"
        "plane-redis"
        "plane-mq"
      ];
      extraOptions = networkOptions "beat-worker";
      volumes = [ "${data "logs-beat-worker"}:/code/plane/logs" ];
    };

    plane-migrator = backend // {
      cmd = [ "./bin/docker-entrypoint-migrator.sh" ];
      dependsOn = [
        "plane-db"
        "plane-redis"
      ];
      extraOptions = networkOptions "migrator";
      volumes = [ "${data "logs-migrator"}:/code/plane/logs" ];
    };

    plane-db = {
      image = "postgres:15.7-alpine";
      cmd = [
        "postgres"
        "-c"
        "max_connections=1000"
      ];
      environment = dbEnv;
      environmentFiles = [ planeSecret ];
      extraOptions = networkOptions null;
      volumes = [ "${data "postgres"}:/var/lib/postgresql/data" ];
    };

    plane-redis = {
      image = "valkey/valkey:7.2.11-alpine";
      extraOptions = networkOptions null;
      volumes = [ "${data "redis"}:/data" ];
    };

    plane-mq = {
      image = "rabbitmq:3.13.6-management-alpine";
      environment = mqEnv;
      environmentFiles = [ planeSecret ];
      extraOptions = networkOptions null;
      volumes = [ "${data "rabbitmq"}:/var/lib/rabbitmq" ];
    };

    plane-minio = {
      image = "minio/minio:latest";
      cmd = [
        "server"
        "/export"
        "--console-address"
        ":9090"
      ];
      environmentFiles = [ planeSecret ];
      extraOptions = networkOptions null;
      volumes = [ "${data "minio"}:/export" ];
    };

    plane-proxy = {
      image = "makeplane/plane-proxy:${planeTag}";
      dependsOn = [
        "plane-web"
        "plane-api"
        "plane-space"
        "plane-admin"
        "plane-live"
      ];
      environment = proxyEnv;
      ports = [ "${server.lan.serverIp}:${toString hostPort}:80" ];
      volumes = [
        "${data "proxy-config"}:/config"
        "${data "proxy-data"}:/data"
      ];
      extraOptions = networkOptions "proxy";
    };
  };

  planeContainerNames = builtins.attrNames planeContainers;
  planeUnits = map (name: "docker-${name}") planeContainerNames;
in
{
  virtualisation.oci-containers.containers = planeContainers;

  networking.firewall.interfaces.${server.lan.interface}.allowedTCPPorts = [ hostPort ];

  systemd.tmpfiles.rules = [
    "d ${planeDataRoot} 0755 root ${appData.group.name} - -"
  ]
  ++ map (name: "d ${data name} 0755 root ${appData.group.name} - -") [
    "logs-api"
    "logs-worker"
    "logs-beat-worker"
    "logs-migrator"
    "postgres"
    "redis"
    "rabbitmq"
    "minio"
    "proxy-config"
    "proxy-data"
  ];

  systemd.services =
    lib.genAttrs planeUnits (_: {
      after = [ "plane-network.service" ];
      requires = [ "plane-network.service" ];
      unitConfig.AssertPathExists = planeSecret;
    })
    // {
      plane-network = {
        description = "Create the Plane container network";
        after = [ "docker.service" ];
        requires = [ "docker.service" ];
        path = [ config.virtualisation.docker.package ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
        };
        script = ''
          docker network inspect ${planeNetwork} >/dev/null 2>&1 \
            || docker network create ${planeNetwork} >/dev/null
        '';
      };
    };

  virtualisation.vmVariant.virtualisation.oci-containers.containers =
    lib.genAttrs planeContainerNames
      (_: {
        autoStart = lib.mkForce false;
      });
}
