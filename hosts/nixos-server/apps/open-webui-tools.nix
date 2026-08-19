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
in
{
  services.searx = {
    enable = true;
    openFirewall = true;
    environmentFile = "${secretsDir}/searxng.env";
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

  systemd.tmpfiles.rules = [
    "d ${secretsDir} 0700 root root - -"
    "Z ${secretsDir} ~0700 root root - -"
    "z ${secretsDir}/searxng.env 0400 root root - -"
  ];

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
