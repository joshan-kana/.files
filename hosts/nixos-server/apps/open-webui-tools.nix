{
  config,
  pkgs,
  ...
}:

let
  serverCfg = config.dotfiles.server;
  inherit (serverCfg) secretsDir;
  serverIp = serverCfg.lan.serverIp;
  searxPort = 8888;
  githubMcpPort = 8082;
  searxEnv = "${secretsDir}/searxng.env";
in
{
  services.searx = {
    enable = true;
    openFirewall = true;
    environmentFile = searxEnv;
    settings = {
      server = {
        port = searxPort;
        bind_address = serverIp;
        secret_key = "$SEARX_SECRET_KEY";
        limiter = false;
        image_proxy = true;
      };
      search.formats = [
        "html"
        "json"
      ];
    };
  };

  systemd.services.searx = {
    after = [ "searxng-secrets.service" ];
    requires = [ "searxng-secrets.service" ];
  };

  systemd.services.searxng-secrets = {
    description = "Provision persistent SearXNG secrets";
    before = [ "searx.service" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      UMask = "0077";
    };
    path = with pkgs; [
      coreutils
      gnugrep
      openssl
    ];
    script = ''
      set -euo pipefail

      install -d -m 0700 ${secretsDir}
      touch ${searxEnv}
      chmod 0400 ${searxEnv}

      if ! grep -q '^SEARX_SECRET_KEY=' ${searxEnv}; then
        chmod 0600 ${searxEnv}
        printf 'SEARX_SECRET_KEY=%s\n' "$(openssl rand -hex 32)" >> ${searxEnv}
        chmod 0400 ${searxEnv}
      fi
    '';
  };

  systemd.services.github-mcp-server = {
    description = "GitHub MCP Server (Streamable HTTP)";
    wantedBy = [ "multi-user.target" ];
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];

    serviceConfig = {
      Type = "simple";
      DynamicUser = true;
      ExecStart = "${pkgs.github-mcp-server}/bin/github-mcp-server http --listen-host ${serverIp} --port ${toString githubMcpPort} --scope-challenge";
      Restart = "on-failure";
      RestartSec = "5s";
      NoNewPrivileges = true;
      PrivateTmp = true;
      ProtectHome = true;
      ProtectSystem = "strict";
      ProtectKernelTunables = true;
      ProtectKernelModules = true;
      ProtectControlGroups = true;
      RestrictAddressFamilies = [
        "AF_INET"
        "AF_INET6"
        "AF_UNIX"
      ];
    };
  };

  networking.firewall.allowedTCPPorts = [ githubMcpPort ];
}
