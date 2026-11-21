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
  parallelsSudoSshKeySecret = "${server.secretsDir}/nixos-arm-parallels-sudo";
  sudoSshKeySecret = "${server.secretsDir}/chatgpt-shell-sudo";
  githubSecret = "${server.secretsDir}/github-self-hosted-agents.env";
  knownHostsFile = "${config.users.users.${primary.name}.home}/.ssh/known_hosts";
  remoteAuthAgentSocket = "/run/chatgpt-shell-access/remote-sudo-agent.sock";
  workerUser = "herdr-worker";

  macHost = "mac.home";
  parallelsHost = "nixos-arm-parallels.home";

  remoteTargets = {
    mac = {
      sshTarget = "${workerUser}@${macHost}";
      credential = macSshKeySecret;
      shell = "/bin/zsh";
      forwardAgent = false;
    };
    nixos-arm-parallels = {
      sshTarget = "${workerUser}@${parallelsHost}";
      credential = macSshKeySecret;
      shell = "/run/current-system/sw/bin/bash";
      forwardAgent = false;
    };
  };
  localWorker = {
    ssh_target = "${workerUser}@127.0.0.1";
    credential = "chatgpt-shell-mac";
    shell = "/run/current-system/sw/bin/bash";
    forwardAgent = false;
  };
  remoteTargetConfig = lib.mapAttrs (_: target: {
    ssh_target = target.sshTarget;
    credential = "chatgpt-shell-mac";
    inherit (target) shell forwardAgent;
  }) remoteTargets;
  policyDefaults = pkgs.writeText "chatgpt-shell-policies.json" (
    builtins.toJSON {
      "${config.networking.hostName}" = {
        commands = "automatic";
        elevation = "ask";
      };
      mac = {
        commands = "ask";
        elevation = "deny";
      };
      nixos-arm-parallels = {
        commands = "automatic";
        elevation = "ask";
      };
    }
  );
  approvalCommand = pkgs.writeShellScriptBin "chatgpt-shell-approval" ''
    export CHATGPT_SHELL_APPROVAL_DIR=/run/chatgpt-shell-access/approvals
    export CHATGPT_SHELL_STATE_DIR=/var/lib/chatgpt-shell-access
    export CHATGPT_SHELL_POLICIES_FILE=${policyDefaults}
    exec ${pkgs.python3}/bin/python3 ${./.}/authorization.py "$@"
  '';
  shellPackages = with pkgs; [
    herdr-core
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
  users.groups.${workerUser} = { };
  users.users.${workerUser} = {
    isSystemUser = true;
    group = workerUser;
    home = "/var/lib/${workerUser}";
    createHome = true;
    shell = pkgs.bashInteractive;
    linger = true;
    openssh.authorizedKeys.keys = [
      "restrict ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHgLTjmo6ZPfUNMxnT2/Yp0ZHJTon28vCVDmbxjMRNuS chatgpt-shell@nixos-server"
    ];
  };

  environment.systemPackages = [
    pkgs.herdr-core
    pkgs.procps
    approvalCommand
  ];

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
      MCP_COMMAND = "${pkgs.coreutils}/bin/env -u CONTROL_PLANE_API_KEY -u CONTROL_PLANE_TUNNEL_ID ${pkgs.chatgpt-shell-mcp-python}/bin/python3 ${./.}/chatgpt-shell-access.py";
      CHATGPT_SHELL_COMMAND_PATH = lib.makeBinPath shellPackages;
      CHATGPT_SHELL_LOCAL_HOST = config.networking.hostName;
      CHATGPT_SHELL_PRIMARY_USER = primary.name;
      CHATGPT_SHELL_LOCAL_WORKER = builtins.toJSON localWorker;
      CHATGPT_SHELL_BASH = "${pkgs.bash}/bin/bash";
      CHATGPT_SHELL_HC = "${pkgs.herdr-core}/bin/hc";
      CHATGPT_SHELL_KNOWN_HOSTS = "/run/chatgpt-shell-access/known_hosts";
      CHATGPT_SHELL_APPROVAL_DIR = "/run/chatgpt-shell-access/approvals";
      CHATGPT_SHELL_STATE_DIR = "/var/lib/chatgpt-shell-access";
      CHATGPT_SHELL_POLICIES_FILE = toString policyDefaults;
      CHATGPT_SHELL_REMOTE_AUTH_AGENT = remoteAuthAgentSocket;
      CHATGPT_SHELL_REMOTE_TARGETS = builtins.toJSON remoteTargetConfig;
    };

    serviceConfig = {
      Type = "simple";
      User = primary.name;
      RuntimeDirectory = "chatgpt-shell-access";
      RuntimeDirectoryMode = "0700";
      StateDirectory = "chatgpt-shell-access";
      StateDirectoryMode = "0700";
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
        ${pkgs.coreutils}/bin/install -m 0600 "$CREDENTIALS_DIRECTORY/chatgpt-shell-known-hosts" "$RUNTIME_DIRECTORY/known_hosts"
        ${pkgs.gawk}/bin/awk '{ print "127.0.0.1 " $1 " " $2 }' /etc/ssh/ssh_host_ed25519_key.pub >> "$RUNTIME_DIRECTORY/known_hosts"
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
