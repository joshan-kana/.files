{
  config,
  inputs,
  lib,
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

  # The server gets the LAN view of mac.home, so keep the stable Tailscale
  # hostname as a transport fallback for when the Mac roams.
  macHost = "mac.home";
  macTailnetHost = "joshans-macbook-pro.tailba46a0.ts.net";
  macHostKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIImH30rGwro6wEvQ9mBHhgY7LLmm7cjobmw+IBv67Qjq";
  macKnownHosts = pkgs.writeText "chatgpt-shell-known-hosts" ''
    ${macHost} ${macHostKey}
  '';
  macProxy = pkgs.writeShellScript "chatgpt-shell-mac-proxy" ''
    set -u
    port="$1"

    ${pkgs.socat}/bin/socat - "TCP:${macHost}:$port,connect-timeout=2" ||
      exec ${pkgs.socat}/bin/socat - "TCP:${macTailnetHost}:$port,connect-timeout=5"
  '';

  remoteTargets = {
    mac = {
      sshTarget = "${primary.name}@${macHost}";
      sshOptions = [ "-oProxyCommand=${macProxy} %p" ];
      credential = macSshKeySecret;
      shell = "/bin/zsh";
      sudo = false;
    };
  };
  remoteTargetConfig = lib.mapAttrs (name: target: {
    ssh_target = target.sshTarget;
    ssh_options = target.sshOptions;
    credential = "chatgpt-shell-${name}";
    inherit (target) shell sudo;
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

  tunnelClient = import ../openai-tunnel-client.nix { inherit inputs pkgs; };
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
      sudoSshKeySecret
      githubSecret
    ]
    ++ lib.mapAttrsToList (_: target: target.credential) remoteTargets;

    path = shellPackages;

    environment = {
      HEALTH_LISTEN_ADDR = "127.0.0.1:18792";
      SSH_AUTH_SOCK = "/run/chatgpt-shell-access/sudo-agent.sock";
      MCP_COMMAND = "${pkgs.coreutils}/bin/env -u CONTROL_PLANE_API_KEY -u CONTROL_PLANE_TUNNEL_ID ${
        pkgs.callPackage ./mcp-package.nix { python = pkgs.python3; }
      }/bin/python3 ${./chatgpt-shell-access.py}";
      CHATGPT_SHELL_COMMAND_PATH = lib.makeBinPath shellPackages;
      CHATGPT_SHELL_LOCAL_USER = primary.name;
      CHATGPT_SHELL_BASH = "${pkgs.bash}/bin/bash";
      CHATGPT_SHELL_REMOTE_TARGETS = builtins.toJSON remoteTargetConfig;
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
      LoadCredential =
        lib.mapAttrsToList (name: target: "chatgpt-shell-${name}:${target.credential}") remoteTargets
        ++ [
          "chatgpt-shell-sudo:${sudoSshKeySecret}"
          "chatgpt-shell-known-hosts:${macKnownHosts}"
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
        exec ${tunnelClient}/bin/tunnel-client run --log.level=info --log.format=struct-text
      '';
      Restart = "always";
      RestartSec = "2s";
      UMask = "0077";
    };
  };
}
