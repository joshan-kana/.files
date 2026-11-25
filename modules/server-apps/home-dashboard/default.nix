{
  config,
  lib,
  pkgs,
  ...
}:

let
  inherit (config.dotfiles) server;
  appData = server.storage.appData;
  stateDir = "${appData.root}/home-dashboard";
  pkg = pkgs.callPackage ./package.nix { };
  listenPort = 8443;
  certDir = "${server.secretsDir}/internal-tls";
  inherit (config) services;
  inherit (config.virtualisation.oci-containers) containers;
  serverHost = "${config.networking.hostName}.home";
  http = port: "http://${serverHost}:${toString port}";
  publishedPort =
    container: port:
    let
      binding = lib.findFirst (
        value: lib.hasSuffix ":${toString port}" value
      ) null containers.${container}.ports;
      parts = lib.splitString ":" binding;
    in
    builtins.elemAt parts (builtins.length parts - 2);
  # The catalog describes known integrations; deployment URLs come from the
  # evaluated service definitions or application-managed protocol defaults.
  appUrls =
    lib.optionalAttrs services.home-assistant.enable { ha = "http://ha.home:8123"; }
    // lib.optionalAttrs services.jellyfin.enable { jellyfin = http 8096; }
    // lib.optionalAttrs services.sonarr.enable { sonarr = http services.sonarr.settings.server.port; }
    // lib.optionalAttrs services.radarr.enable { radarr = http services.radarr.settings.server.port; }
    // lib.optionalAttrs services.prowlarr.enable {
      prowlarr = http services.prowlarr.settings.server.port;
    }
    // lib.optionalAttrs services.bazarr.enable { bazarr = http services.bazarr.settings.general.port; }
    // lib.optionalAttrs services.transmission.enable {
      transmission = http services.transmission.settings.rpc-port;
    }
    // lib.optionalAttrs services.seerr.enable { seerr = http services.seerr.port; }
    // lib.optionalAttrs (containers ? streamystats) {
      streamystats = http (publishedPort "streamystats" 3000);
    }
    // lib.optionalAttrs services.immich.enable { immich = http services.immich.port; }
    // lib.optionalAttrs services.paperless.enable { paperless = http services.paperless.port; }
    // lib.optionalAttrs (containers ? n8n) { n8n = "http://n8n.home:${publishedPort "n8n" 5678}"; }
    // lib.optionalAttrs services.open-webui.enable { openwebui = http services.open-webui.port; }
    // lib.optionalAttrs (config.systemd.services ? open-webui-computer) {
      computer = http config.systemd.services.open-webui-computer.environment.CPTR_PORT;
    }
    // lib.optionalAttrs services.openclaw-gateway.enable {
      openclaw = "https://${serverHost}:${toString services.openclaw-gateway.port}";
    }
    // lib.optionalAttrs services.gitea.enable {
      gitea = http services.gitea.settings.server.HTTP_PORT;
    }
    // lib.optionalAttrs services.gerrit.enable {
      gerrit = services.gerrit.settings.gerrit.canonicalWebUrl;
    }
    // lib.optionalAttrs (containers ? onedev) { onedev = http (publishedPort "onedev" 6610); }
    // lib.optionalAttrs (containers ? agent-mail) {
      agentmail = "${http containers.agent-mail.environment.HTTP_PORT}/mail/";
    }
    // lib.optionalAttrs services.adguardhome.enable {
      adguard = "http://dns.home:${lib.last (lib.splitString ":" services.adguardhome.settings.http.address)}";
    }
    // lib.optionalAttrs services.technitium-dns-server.enable { technitium = http 5380; }
    // lib.optionalAttrs services.ntfy-sh.enable { ntfy = services.ntfy-sh.settings."base-url"; };
  upstreams =
    lib.optionalAttrs services.home-assistant.enable { homeassistant = "http://127.0.0.1:8123"; }
    // lib.optionalAttrs services.sonarr.enable {
      sonarr = "http://127.0.0.1:${toString services.sonarr.settings.server.port}";
    }
    // lib.optionalAttrs services.radarr.enable {
      radarr = "http://127.0.0.1:${toString services.radarr.settings.server.port}";
    };
in
{
  users.groups.home-dashboard = { };
  users.users.home-dashboard = {
    isSystemUser = true;
    group = "home-dashboard";
  };

  systemd.services.home-dashboard = {
    description = "Private unified home dashboard";
    wantedBy = [ "multi-user.target" ];
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    environment = {
      DASHBOARD_LISTEN = "127.0.0.1:8777";
      DASHBOARD_DATA_DIR = stateDir;
      DASHBOARD_APP_URLS = builtins.toJSON appUrls;
      DASHBOARD_UPSTREAMS = builtins.toJSON upstreams;
      DASHBOARD_PUBLIC_ORIGIN = "https://${serverHost}:${toString listenPort}";
    };
    serviceConfig = {
      Type = "simple";
      User = "home-dashboard";
      Group = "home-dashboard";
      ExecStart = lib.getExe pkg;
      WorkingDirectory = stateDir;
      Restart = "on-failure";
      RestartSec = 3;
      UMask = "0077";
      NoNewPrivileges = true;
      PrivateTmp = true;
      ProtectSystem = "strict";
      ProtectHome = true;
      ReadWritePaths = [ stateDir ];
      RestrictAddressFamilies = [
        "AF_INET"
        "AF_INET6"
        "AF_UNIX"
      ];
    };
  };

  systemd.tmpfiles.rules = [
    "d ${stateDir} 0700 home-dashboard home-dashboard - -"
    "a+ ${appData.root} - - - - u:home-dashboard:--x"
  ];

  systemd.services.nginx.serviceConfig.LoadCredential = [
    "home-dashboard.crt:${certDir}/${serverHost}.crt"
    "home-dashboard.key:${certDir}/${serverHost}.key"
  ];

  config.services.nginx = {
    enable = true;
    virtualHosts.${serverHost} = {
      onlySSL = true;
      listen = [
        {
          addr = "0.0.0.0";
          port = listenPort;
          ssl = true;
        }
        {
          addr = "[::]";
          port = listenPort;
          ssl = true;
        }
      ];
      sslCertificate = "/run/credentials/nginx.service/home-dashboard.crt";
      sslCertificateKey = "/run/credentials/nginx.service/home-dashboard.key";
      locations."/".proxyPass = "http://127.0.0.1:8777";
      extraConfig = ''
        add_header X-Content-Type-Options nosniff always;
      '';
    };
  };

  networking.firewall.interfaces.${server.lan.interface}.allowedTCPPorts = [ listenPort ];

  virtualisation.vmVariant.dotfiles.scopes.serverApps.homeDashboard.enable = lib.mkForce false;
}
