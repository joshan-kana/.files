{
  config,
  lib,
  pkgs,
  ...
}:

let
  inherit (config.dotfiles) server;
  inherit (config.dotfiles.users) primary;
  tunnelSecret = "${server.secretsDir}/chatgpt-shell-tunnel.env";
  githubSecret = "${server.secretsDir}/github-self-hosted-agents.env";
  knownHostsFile = "${config.users.users.${primary.name}.home}/.ssh/known_hosts";
  remoteAuthAgentSocket = "/run/chatgpt-shell-access/remote-sudo-agent.sock";

  remoteTargets = {
    mac = {
      shell = "/bin/zsh";
      forwardAgent = false;
    };
    nixos-arm-parallels = {
      shell = "/run/current-system/sw/bin/bash";
      forwardAgent = true;
    };
    nixos-pi = {
      shell = "/run/current-system/sw/bin/bash";
      forwardAgent = true;
    };
  };
  remoteTargetConfig = lib.mapAttrs (name: target: {
    ssh_target = "${primary.name}@${name}.home";
    credential = "chatgpt-shell-${name}";
    inherit (target) shell forwardAgent;
  }) remoteTargets;
  remoteElevationCredentials = map (name: "${name}-sudo") (
    lib.attrNames (lib.filterAttrs (_: target: target.forwardAgent) remoteTargets)
  );
  credentials =
    lib.genAttrs (
      [ "chatgpt-shell-sudo" ]
      ++ map (name: "chatgpt-shell-${name}") (lib.attrNames remoteTargets)
      ++ remoteElevationCredentials
    ) (name: "${server.secretsDir}/${name}")
    // {
      chatgpt-shell-known-hosts = knownHostsFile;
    };
  shellPackages = with pkgs; [
    bash
    coreutils
    curl
    diffutils
    file
    findutils
    gawk
    gh
    git
    gnugrep
    gnupatch
    gnused
    iproute2
    jq
    openssh
    procps
    psmisc
    python3
    ripgrep
    rsync
    systemd
    util-linux
    "/run/current-system/sw"
  ];
in
{
  systemd.tmpfiles.rules = [
    "f+ /etc/chatgpt-shell-sudo-authorized-key 0444 root root - ssh-ed25519\\x20AAAAC3NzaC1lZDI1NTE5AAAAIEp/T7PcjFts+DbMZnJrMle2UhBtWhJ2ycLYIlFMNkIu\\x20chatgpt-shell-sudo\\n"
  ];

  systemd.services.chatgpt-shell-access = {
    description = "ChatGPT shell access through OpenAI Secure MCP Tunnel";
    wantedBy = [ "multi-user.target" ];
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];

    unitConfig.AssertPathExists = [
      tunnelSecret
      githubSecret
    ]
    ++ lib.attrValues credentials;

    path = shellPackages;

    environment = {
      HEALTH_LISTEN_ADDR = "127.0.0.1:18792";
      SSH_AUTH_SOCK = "/run/chatgpt-shell-access/sudo-agent.sock";
      MCP_COMMAND = "${pkgs.coreutils}/bin/env -u CONTROL_PLANE_API_KEY -u CONTROL_PLANE_TUNNEL_ID ${pkgs.chatgpt-shell-mcp-python}/bin/python3 ${./chatgpt-shell-access.py}";
      CHATGPT_SHELL_COMMAND_PATH = lib.makeBinPath shellPackages;
      CHATGPT_SHELL_LOCAL_HOST = config.networking.hostName;
      CHATGPT_SHELL_BASH = "${pkgs.bash}/bin/bash";
      CHATGPT_SHELL_REMOTE_AUTH_AGENT = remoteAuthAgentSocket;
      CHATGPT_SHELL_REMOTE_TARGETS = builtins.toJSON remoteTargetConfig;
    };

    serviceConfig = {
      Type = "simple";
      User = primary.name;
      RuntimeDirectory = "chatgpt-shell-access";
      RuntimeDirectoryMode = "0770";
      EnvironmentFile = [
        tunnelSecret
        githubSecret
      ];
      LoadCredential = lib.mapAttrsToList (name: path: "${name}:${path}") credentials;
      ExecStart = pkgs.writeShellScript "chatgpt-shell-access-start" ''
        set -euo pipefail
        rm -f "$SSH_AUTH_SOCK" "$CHATGPT_SHELL_REMOTE_AUTH_AGENT"
        ${pkgs.openssh}/bin/ssh-agent -D -a "$SSH_AUTH_SOCK" >/dev/null &
        ${pkgs.openssh}/bin/ssh-agent -D -a "$CHATGPT_SHELL_REMOTE_AUTH_AGENT" >/dev/null &
        for _ in $(seq 1 100); do
          [ -S "$SSH_AUTH_SOCK" ] && [ -S "$CHATGPT_SHELL_REMOTE_AUTH_AGENT" ] && break
          sleep 0.05
        done
        [ -S "$SSH_AUTH_SOCK" ]
        [ -S "$CHATGPT_SHELL_REMOTE_AUTH_AGENT" ]
        ${pkgs.openssh}/bin/ssh-add - < "$CREDENTIALS_DIRECTORY/chatgpt-shell-sudo"
        for credential in ${lib.escapeShellArgs remoteElevationCredentials}; do
          SSH_AUTH_SOCK="$CHATGPT_SHELL_REMOTE_AUTH_AGENT" ${pkgs.openssh}/bin/ssh-add - < "$CREDENTIALS_DIRECTORY/$credential"
        done
        exec ${pkgs.openai-tunnel-client}/bin/tunnel-client run --log.level=info --log.format=struct-text
      '';
      Restart = "always";
      RestartSec = "2s";
      UMask = "0077";
    };
  };
}
