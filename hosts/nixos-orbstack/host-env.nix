{ ... }:

{
  environment.sessionVariables = {
    # OrbStack forwards the host (macOS) SSH agent via this socket.
    # Setting it here makes it available even in non-SSH sessions.
    SSH_AUTH_SOCK = "/opt/orbstack-guest/run/host-ssh-agent.sock";
  };

  programs.ssh.extraConfig = ''
    Host *
      ForwardAgent yes
  '';
}
