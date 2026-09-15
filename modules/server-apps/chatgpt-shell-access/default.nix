{
  config,
  pkgs,
  ...
}:

let
  inherit (config.dotfiles) server;
  inherit (config.dotfiles.users) primary;
  serviceUser = "chatgpt-shell";
  tunnelSecret = "${server.secretsDir}/chatgpt-shell-tunnel.env";
  macSshKeySecret = "${server.secretsDir}/chatgpt-shell-mac";
  sudoSshKeySecret = "${server.secretsDir}/chatgpt-shell-sudo";
  githubSecret = "${server.secretsDir}/github-self-hosted-agents.env";
  macKnownHostsFile = "${config.users.users.${primary.name}.home}/.ssh/known_hosts";

  tunnelClientVersion = "0.0.11";
  tunnelClientPlatform =
    {
      "aarch64-linux" = {
        asset = "linux-arm64";
        hash = "sha256-2LukeypyN5mjcrC4fX5NaTBAk9OiiDcjcxX+VAbZfnc=";
      };
      "x86_64-linux" = {
        asset = "linux-amd64";
        hash = "sha256-Ka3+XBOZ37n9qTg/IwwyQ1WRL1DcNuLkFrHxMiMXs8Q=";
      };
    }
    .${pkgs.stdenv.hostPlatform.system}
      or (throw "Unsupported tunnel-client platform: ${pkgs.stdenv.hostPlatform.system}");
in
{
  users.groups.${serviceUser} = { };
  users.users.${serviceUser} = {
    isSystemUser = true;
    group = serviceUser;
  };
  users.users.${primary.name}.extraGroups = [ serviceUser ];

  security.pam.sshAgentAuth.authorizedKeysFiles = [ "/etc/chatgpt-shell-sudo-authorized-key" ];

  systemd.tmpfiles.rules = [
    "f+ /etc/chatgpt-shell-sudo-authorized-key 0444 root root - ssh-ed25519\\x20AAAAC3NzaC1lZDI1NTE5AAAAIEp/T7PcjFts+DbMZnJrMle2UhBtWhJ2ycLYIlFMNkIu\\x20chatgpt-shell-sudo\\n"
  ];

  security.sudo.extraRules = [
    {
      users = [ serviceUser ];
      runAs = primary.name;
      commands = [
        {
          command = "${pkgs.bash}/bin/bash";
          options = [ "NOPASSWD" ];
        }
      ];
    }
  ];

  security.sudo.extraConfig = ''
    Defaults:${serviceUser} env_keep += "GH_TOKEN"
  '';

  systemd.services.chatgpt-shell-access = {
    description = "ChatGPT shell access through OpenAI Secure MCP Tunnel";
    wantedBy = [ "multi-user.target" ];
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];

    unitConfig.AssertPathExists = [
      tunnelSecret
      macSshKeySecret
      sudoSshKeySecret
      githubSecret
      macKnownHostsFile
    ];

    path = with pkgs; [
      bash
      coreutils
      curl
      gawk
      gh
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
      MCP_COMMAND = "${pkgs.coreutils}/bin/env -u CONTROL_PLANE_API_KEY -u CONTROL_PLANE_TUNNEL_ID -u OPENAI_API_KEY ${
        pkgs.callPackage ./mcp-package.nix { python = pkgs.python3; }
      }/bin/python3 ${./chatgpt-shell-access.py}";
      CHATGPT_SHELL_LOCAL_USER = primary.name;
      CHATGPT_SHELL_BASH = "${pkgs.bash}/bin/bash";
      CHATGPT_SHELL_MAC_SSH_TARGET = "${primary.name}@Joshans-MacBook-Pro.local";
    };

    serviceConfig = {
      Type = "simple";
      User = serviceUser;
      RuntimeDirectory = "chatgpt-shell-access";
      RuntimeDirectoryMode = "0770";
      EnvironmentFile = [
        tunnelSecret
        githubSecret
      ];
      LoadCredential = [
        "chatgpt-shell-mac:${macSshKeySecret}"
        "chatgpt-shell-sudo:${sudoSshKeySecret}"
        "chatgpt-shell-known-hosts:${macKnownHostsFile}"
      ];
      ExecStart = pkgs.writeShellScript "chatgpt-shell-access-start" ''
        set -euo pipefail
        rm -f "$SSH_AUTH_SOCK"
        /run/wrappers/bin/sudo -n -H -u ${primary.name} -- ${pkgs.bash}/bin/bash -c \
          'exec ${pkgs.openssh}/bin/ssh-agent -D -a "$1"' _ "$SSH_AUTH_SOCK" >/dev/null &
        for _ in $(seq 1 100); do
          [ -S "$SSH_AUTH_SOCK" ] && break
          sleep 0.05
        done
        [ -S "$SSH_AUTH_SOCK" ]
        cat "$CREDENTIALS_DIRECTORY/chatgpt-shell-sudo" | \
          /run/wrappers/bin/sudo -n -H -u ${primary.name} -- ${pkgs.bash}/bin/bash -c \
            'SSH_AUTH_SOCK="$1" exec ${pkgs.openssh}/bin/ssh-add -' _ "$SSH_AUTH_SOCK"
        exec ${
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
            ''
        }/bin/tunnel-client run --log.level=info --log.format=struct-text
      '';
      Restart = "always";
      RestartSec = "2s";
      UMask = "0077";
    };
  };
}
