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
  enabledScopes = config.dotfiles.resolvedScopes.serverApps;
  enabledAppSpecs = [
    {
      id = "ha";
      enabled = enabledScopes.homeAssistant.enable;
    }
    {
      id = "jellyfin";
      enabled = enabledScopes.jellyfin.enable;
    }
    {
      id = "sonarr";
      enabled = enabledScopes.servarr.sonarr.enable;
    }
    {
      id = "radarr";
      enabled = enabledScopes.servarr.radarr.enable;
    }
    {
      id = "prowlarr";
      enabled = enabledScopes.servarr.prowlarr.enable;
    }
    {
      id = "bazarr";
      enabled = enabledScopes.servarr.bazarr.enable;
    }
    {
      id = "transmission";
      enabled = enabledScopes.servarr.transmission.enable;
    }
    {
      id = "seerr";
      enabled = enabledScopes.servarr.seerr.enable;
    }
    {
      id = "streamystats";
      enabled = enabledScopes.servarr.streamystats.enable;
    }
    {
      id = "immich";
      enabled = enabledScopes.immich.enable;
    }
    {
      id = "paperless";
      enabled = enabledScopes.paperless.enable;
    }
    {
      id = "n8n";
      enabled = enabledScopes.n8n.enable;
    }
    {
      id = "openwebui";
      enabled = enabledScopes.openWebui.enable;
    }
    {
      id = "computer";
      enabled = enabledScopes.openWebui.computer.enable;
    }
    {
      id = "openclaw";
      enabled = enabledScopes.openclaw.enable;
    }
    {
      id = "gitea";
      enabled = enabledScopes.gitea.enable;
    }
    {
      id = "gerrit";
      enabled = enabledScopes.gerrit.enable;
    }
    {
      id = "onedev";
      enabled = enabledScopes.onedev.enable;
    }
    {
      id = "agentmail";
      enabled = enabledScopes.agentTools.agentMail.enable;
    }
    {
      id = "adguard";
      enabled = config.services.adguardhome.enable;
    }
    {
      id = "technitium";
      enabled = config.services.technitium-dns-server.enable;
    }
    {
      id = "ntfy";
      enabled = enabledScopes.ntfy.enable;
    }
  ];
  enabledApps = lib.concatStringsSep "," (
    lib.concatMap (app: lib.optional app.enabled app.id) enabledAppSpecs
  );
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
      DASHBOARD_ENABLED_APPS = enabledApps;
      DASHBOARD_PUBLIC_ORIGIN = "https://nixos-server.home:${toString listenPort}";
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
    "home-dashboard.crt:${certDir}/nixos-server.home.crt"
    "home-dashboard.key:${certDir}/nixos-server.home.key"
  ];

  services.nginx = {
    enable = true;
    virtualHosts."nixos-server.home" = {
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
