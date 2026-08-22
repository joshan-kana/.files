{
  config,
  pkgs,
  ...
}:

let
  primaryUser = config.dotfiles.users.primary.name;
  primaryHome = config.users.users.${primaryUser}.home;
  serviceUser = "chatgpt-shell";
  secretsDir = config.dotfiles.server.secretsDir;
  mcpScript = ./chatgpt-shell-access.py;
  tunnelEnvironmentFile = "${secretsDir}/chatgpt-shell-tunnel.env";
  macSshKeyFile = "${secretsDir}/chatgpt-shell-mac";
  sudoSshKeyFile = "${secretsDir}/chatgpt-shell-sudo";
  macKnownHostsFile = "${primaryHome}/.ssh/known_hosts";

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

  startScript = pkgs.writeShellScript "chatgpt-shell-access-start" ''
    set -euo pipefail
    rm -f "$SSH_AUTH_SOCK"
    /run/wrappers/bin/sudo -n -H -u ${primaryUser} -- ${pkgs.bash}/bin/bash -c \
      'exec ${pkgs.openssh}/bin/ssh-agent -D -a "$1"' _ "$SSH_AUTH_SOCK" >/dev/null &
    for _ in $(seq 1 100); do
      [ -S "$SSH_AUTH_SOCK" ] && break
      sleep 0.05
    done
    [ -S "$SSH_AUTH_SOCK" ]
    cat "$CREDENTIALS_DIRECTORY/chatgpt-shell-sudo" | \
      /run/wrappers/bin/sudo -n -H -u ${primaryUser} -- ${pkgs.bash}/bin/bash -c \
        'SSH_AUTH_SOCK="$1" exec ${pkgs.openssh}/bin/ssh-add -' _ "$SSH_AUTH_SOCK"
    exec ${tunnelClient}/bin/tunnel-client run --log.level=info --log.format=struct-text
  '';
in
{
  users.groups.${serviceUser} = { };
  users.users.${serviceUser} = {
    isSystemUser = true;
    group = serviceUser;
  };
  users.users.${primaryUser}.extraGroups = [ serviceUser ];

  security.sudo.extraRules = [
    {
      users = [ serviceUser ];
      runAs = primaryUser;
      commands = [
        {
          command = "${pkgs.bash}/bin/bash";
          options = [ "NOPASSWD" ];
        }
      ];
    }
  ];

  systemd.services.chatgpt-shell-access = {
    description = "ChatGPT shell access through OpenAI Secure MCP Tunnel";
    wantedBy = [ "multi-user.target" ];
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];

    unitConfig.ConditionPathExists = [
      tunnelEnvironmentFile
      macSshKeyFile
      sudoSshKeyFile
      macKnownHostsFile
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
      HEALTH_LISTEN_ADDR = "127.0.0.1:18792";
      SSH_AUTH_SOCK = "/run/chatgpt-shell-access/sudo-agent.sock";
      MCP_COMMAND = "${pkgs.coreutils}/bin/env -u CONTROL_PLANE_API_KEY -u CONTROL_PLANE_TUNNEL_ID -u OPENAI_API_KEY ${mcpPython}/bin/python3 ${mcpScript}";
      CHATGPT_SHELL_LOCAL_USER = primaryUser;
      CHATGPT_SHELL_BASH = "${pkgs.bash}/bin/bash";
      CHATGPT_SHELL_MAC_SSH_TARGET = "${primaryUser}@Joshans-MacBook-Pro.local";
    };

    serviceConfig = {
      Type = "simple";
      User = serviceUser;
      RuntimeDirectory = "chatgpt-shell-access";
      RuntimeDirectoryMode = "0770";
      EnvironmentFile = tunnelEnvironmentFile;
      LoadCredential = [
        "chatgpt-shell-mac:${macSshKeyFile}"
        "chatgpt-shell-sudo:${sudoSshKeyFile}"
        "chatgpt-shell-known-hosts:${macKnownHostsFile}"
      ];
      ExecStart = startScript;
      Restart = "always";
      RestartSec = "2s";
      UMask = "0077";
    };
  };
}
