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
  macSshKeySecret = "${server.secretsDir}/chatgpt-shell-mac";
  parallelsSshKeySecret = "${server.secretsDir}/chatgpt-shell-nixos-arm-parallels";
  parallelsSudoSshKeySecret = "${server.secretsDir}/nixos-arm-parallels-sudo";
  sudoSshKeySecret = "${server.secretsDir}/chatgpt-shell-sudo";
  githubSecret = "${server.secretsDir}/github-self-hosted-agents.env";
  knownHostsFile = "${config.users.users.${primary.name}.home}/.ssh/known_hosts";
  remoteAuthAgentSocket = "/run/chatgpt-shell-access/remote-sudo-agent.sock";

  macHost = "mac.home";
  parallelsHost = "nixos-arm-parallels.home";

  remoteTargets = {
    mac = {
      sshTarget = "${primary.name}@${macHost}";
      credential = macSshKeySecret;
      shell = "/bin/zsh";
      forwardAgent = false;
    };
    nixos-arm-parallels = {
      sshTarget = "${primary.name}@${parallelsHost}";
      credential = parallelsSshKeySecret;
      shell = "/run/current-system/sw/bin/bash";
      forwardAgent = true;
    };
  };
  remoteTargetConfig = lib.mapAttrs (name: target: {
    ssh_target = target.sshTarget;
    credential = "chatgpt-shell-${name}";
    inherit (target) shell forwardAgent;
  }) remoteTargets;
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
    nix
    openssh
    procps
    psmisc
    python3
    ripgrep
    rsync
    systemd
    util-linux
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
      sudoSshKeySecret
      parallelsSudoSshKeySecret
      githubSecret
      knownHostsFile
    ]
    ++ lib.mapAttrsToList (_: target: target.credential) remoteTargets;

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
      LoadCredential =
        lib.mapAttrsToList (name: target: "chatgpt-shell-${name}:${target.credential}") remoteTargets
        ++ [
          "chatgpt-shell-sudo:${sudoSshKeySecret}"
          "nixos-arm-parallels-sudo:${parallelsSudoSshKeySecret}"
          "chatgpt-shell-known-hosts:${knownHostsFile}"
        ];
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
        cat "$CREDENTIALS_DIRECTORY/chatgpt-shell-sudo" | \
          ${pkgs.bash}/bin/bash -c \
            'SSH_AUTH_SOCK="$1" exec ${pkgs.openssh}/bin/ssh-add -' _ "$SSH_AUTH_SOCK"
        cat "$CREDENTIALS_DIRECTORY/nixos-arm-parallels-sudo" | \
          ${pkgs.bash}/bin/bash -c \
            'SSH_AUTH_SOCK="$1" exec ${pkgs.openssh}/bin/ssh-add -' _ "$CHATGPT_SHELL_REMOTE_AUTH_AGENT"
        exec ${pkgs.openai-tunnel-client}/bin/tunnel-client run --log.level=info --log.format=struct-text
      '';
      Restart = "always";
      RestartSec = "2s";
      UMask = "0077";
    };
  };
}
