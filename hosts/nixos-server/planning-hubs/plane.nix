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
  planeTag = "stable";
  planeEnv = {
    WEB_URL = "http://192.168.1.3:8080";
    CORS_ALLOWED_ORIGINS = "http://192.168.1.3:8080";
    GUNICORN_WORKERS = "1";
    USE_MINIO = "1";
    API_KEY_RATE_LIMIT = "60/minute";
    MINIO_ENDPOINT_SSL = "0";
    WEBHOOK_ALLOWED_IPS = "";
    WEBHOOK_ALLOWED_HOSTS = "";
    PGHOST = "plane-db";
    PGDATABASE = "plane";
    POSTGRES_USER = "plane";
    POSTGRES_DB = "plane";
    POSTGRES_PORT = "5432";
    PGDATA = "/var/lib/postgresql/data";
    REDIS_HOST = "plane-redis";
    REDIS_PORT = "6379";
    REDIS_URL = "redis://plane-redis:6379/";
    RABBITMQ_HOST = "plane-mq";
    RABBITMQ_PORT = "5672";
    RABBITMQ_DEFAULT_USER = "plane";
    RABBITMQ_DEFAULT_PASS = "plane";
    RABBITMQ_DEFAULT_VHOST = "plane";
    RABBITMQ_VHOST = "plane";
    AWS_S3_ENDPOINT_URL = "http://plane-minio:9000";
    AWS_S3_BUCKET_NAME = "uploads";
    BUCKET_NAME = "uploads";
    FILE_SIZE_LIMIT = "5242880";
  };
  proxyEnv = {
    APP_DOMAIN = "192.168.1.3:8080";
    LISTEN_HTTP_PORT = "80";
    LISTEN_HTTPS_PORT = "443";
    SITE_ADDRESS = ":80";
    FILE_SIZE_LIMIT = "5242880";
    CERT_EMAIL = "";
    CERT_ACME_CA = "https://acme-v02.api.letsencrypt.org/directory";
    CERT_ACME_DNS = "";
  };
  envFile = [ "${secretsDir}/plane.env" ];
  data = name: "${planeDataRoot}/${name}";
  planeNetwork = "plane";
  backend = {
    image = "makeplane/plane-backend:${planeTag}";
    environment = planeEnv;
    environmentFiles = envFile;
  };
in
{
  virtualisation.oci-containers.containers = {
    web = {
      image = "makeplane/plane-frontend:${planeTag}";
      dependsOn = [
        "api"
        "worker"
      ];
      extraOptions = [ "--network=${planeNetwork}" ];
      environmentFiles = envFile;
    };
    space = {
      image = "makeplane/plane-space:${planeTag}";
      dependsOn = [
        "api"
        "worker"
        "web"
      ];
      extraOptions = [ "--network=${planeNetwork}" ];
      environmentFiles = envFile;
    };
    admin = {
      image = "makeplane/plane-admin:${planeTag}";
      dependsOn = [
        "api"
        "web"
      ];
      extraOptions = [ "--network=${planeNetwork}" ];
      environmentFiles = envFile;
    };
    live = {
      image = "makeplane/plane-live:${planeTag}";
      dependsOn = [
        "api"
        "web"
      ];
      extraOptions = [ "--network=${planeNetwork}" ];
      environment = planeEnv // {
        API_BASE_URL = "http://api:8000";
      };
      environmentFiles = envFile;
    };
    api = backend // {
      cmd = [ "./bin/docker-entrypoint-api.sh" ];
      dependsOn = [
        "plane-db"
        "plane-redis"
        "plane-mq"
      ];
      extraOptions = [ "--network=${planeNetwork}" ];
      volumes = [ "${data "logs-api"}:/code/plane/logs" ];
    };
    worker = backend // {
      cmd = [ "./bin/docker-entrypoint-worker.sh" ];
      dependsOn = [
        "api"
        "plane-db"
        "plane-redis"
        "plane-mq"
      ];
      extraOptions = [ "--network=${planeNetwork}" ];
      volumes = [ "${data "logs-worker"}:/code/plane/logs" ];
    };
    "beat-worker" = backend // {
      cmd = [ "./bin/docker-entrypoint-beat.sh" ];
      dependsOn = [
        "api"
        "plane-db"
        "plane-redis"
        "plane-mq"
      ];
      extraOptions = [ "--network=${planeNetwork}" ];
      volumes = [ "${data "logs-beat-worker"}:/code/plane/logs" ];
    };
    migrator = backend // {
      cmd = [ "./bin/docker-entrypoint-migrator.sh" ];
      dependsOn = [
        "plane-db"
        "plane-redis"
      ];
      extraOptions = [ "--network=${planeNetwork}" ];
      volumes = [ "${data "logs-migrator"}:/code/plane/logs" ];
    };
    "plane-db" = {
      image = "postgres:15.7-alpine";
      cmd = [
        "postgres"
        "-c"
        "max_connections=1000"
      ];
      environment = planeEnv;
      environmentFiles = envFile;
      extraOptions = [ "--network=${planeNetwork}" ];
      volumes = [ "${data "postgres"}:/var/lib/postgresql/data" ];
    };
    "plane-redis" = {
      image = "valkey/valkey:7.2.11-alpine";
      environmentFiles = envFile;
      volumes = [ "${data "redis"}:/data" ];
      extraOptions = [ "--network=${planeNetwork}" ];
    };
    "plane-mq" = {
      image = "rabbitmq:3.13.6-management-alpine";
      environment = planeEnv;
      environmentFiles = envFile;
      volumes = [ "${data "rabbitmq"}:/var/lib/rabbitmq" ];
      extraOptions = [ "--network=${planeNetwork}" ];
    };
    "plane-minio" = {
      image = "minio/minio:latest";
      cmd = [
        "server"
        "/export"
        "--console-address"
        ":9090"
      ];
      environment = planeEnv;
      environmentFiles = envFile;
      extraOptions = [ "--network=${planeNetwork}" ];
      volumes = [ "${data "minio"}:/export" ];
    };
    proxy = {
      image = "makeplane/plane-proxy:${planeTag}";
      dependsOn = [
        "web"
        "api"
        "space"
        "admin"
        "live"
      ];
      environment = proxyEnv;
      environmentFiles = envFile;
      ports = [ "8080:80" ];
      volumes = [
        "${data "proxy-config"}:/config"
        "${data "proxy-data"}:/data"
      ];
      extraOptions = [ "--network=${planeNetwork}" ];
    };
  };

  systemd.tmpfiles.rules =
    map (name: "d ${data name} 0755 root ${serverCfg.storage.appData.group.name} - -")
      [
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

  networking.firewall.allowedTCPPorts = lib.mkAfter [ 8080 ];
  systemd.services.docker-network-plane = {
    description = "Create the Plane container network";
    wantedBy = [ "docker-plane-db.service" ];
    before = [ "docker-plane-db.service" ];
    after = [ "docker.service" ];
    requires = [ "docker.service" ];
    serviceConfig.Type = "oneshot";
    serviceConfig.RemainAfterExit = true;
    path = [ config.virtualisation.docker.package ];
    script = ''
      ${config.virtualisation.docker.package}/bin/docker network inspect ${planeNetwork} >/dev/null 2>&1 \
        || ${config.virtualisation.docker.package}/bin/docker network create ${planeNetwork}
    '';
  };
  systemd.services.docker-proxy.unitConfig.AssertPathExists = [
    "${secretsDir}/plane.env"
  ];
}
