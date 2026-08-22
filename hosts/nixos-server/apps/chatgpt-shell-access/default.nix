{
  config,
  pkgs,
  ...
}:

let
  primaryUser = config.dotfiles.users.primary.name;
  primaryHome = config.users.users.${primaryUser}.home;
  secretsDir = config.dotfiles.server.secretsDir;
  mcpScript = ./chatgpt-shell-access.py;
  tunnelEnvironmentFile = "${secretsDir}/chatgpt-shell-tunnel.env";
  macSshKeyFile = "${secretsDir}/chatgpt-shell-mac";

  mcpPython = pkgs.callPackage ./mcp-package.nix { python = pkgs.python3; };

  tunnelClientVersion = "0.0.11";
  tunnelClientPlatforms = {
    "aarch64-linux" = {
      asset = "linux-arm64";
      hash = "sha256-2LukeypyN5mjcrC4fX5NaTBAk9OiiDcjcxX+VAbZfnc=";
    };
    "x86_64-linux" = {
      asset = "linux-amd64";
      hash = "sha256-Ka3+XBOZ37n9qTg/IwwyQ1WRL1DcNuLkFrHxMiMXs8Q=";
    };
  };
  tunnelClientPlatform =
    tunnelClientPlatforms.${pkgs.stdenv.hostPlatform.system}
      or (throw "Unsupported tunnel-client platform: ${pkgs.stdenv.hostPlatform.system}");
  tunnelClient =
    pkgs.runCommand "tunnel-client-${tunnelClientVersion}"
      {
        nativeBuildInputs = [ pkgs.unzip ];
      }
      ''
        mkdir -p "$out/bin"
        unzip -j ${
          pkgs.fetchurl {
            url = "https://persistent.oaistatic.com/tunnel-client/v${tunnelClientVersion}/tunnel-client-v${tunnelClientVersion}-${tunnelClientPlatform.asset}.zip";
            inherit (tunnelClientPlatform) hash;
          }
        } tunnel-client -d "$out/bin"
        chmod +x "$out/bin/tunnel-client"
      '';
in
{
  systemd.services.chatgpt-shell-access = {
    description = "ChatGPT shell access through OpenAI Secure MCP Tunnel";
    wantedBy = [ "multi-user.target" ];
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];

    unitConfig.ConditionPathExists = [
      tunnelEnvironmentFile
      macSshKeyFile
    ];

    path = with pkgs; [
      bash
      coreutils
      curl
      gawk
      git
      gnugrep
      gnused
      jq
      nix
      openssh
      rsync
      systemd
      util-linux
    ];

    environment = {
      HOME = primaryHome;
      HEALTH_LISTEN_ADDR = "127.0.0.1:18792";
      MCP_COMMAND = "${pkgs.coreutils}/bin/env -u CONTROL_PLANE_API_KEY -u CONTROL_PLANE_TUNNEL_ID -u OPENAI_API_KEY ${mcpPython}/bin/python3 ${mcpScript}";
      CHATGPT_SHELL_MAC_SSH_TARGET = "${primaryUser}@Joshans-MacBook-Pro.local";
    };

    serviceConfig = {
      Type = "simple";
      User = primaryUser;
      WorkingDirectory = primaryHome;
      EnvironmentFile = tunnelEnvironmentFile;
      LoadCredential = "chatgpt-shell-mac:${macSshKeyFile}";
      ExecStart = "${tunnelClient}/bin/tunnel-client run --log.level=info --log.format=struct-text";
      Restart = "always";
      RestartSec = "2s";
      UMask = "0077";
    };
  };
}
