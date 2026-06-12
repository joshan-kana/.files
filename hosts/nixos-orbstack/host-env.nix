{
  config,
  ...
}:

let
  cfg = config.dotfiles;
  primaryHome = "${cfg.users.primary.homeRoot}/${cfg.users.primary.name}";
  repoPath = "${primaryHome}/${cfg.paths.repoName}";
in
{
  environment.sessionVariables = {
    DOTFILES = repoPath;
    FLK_PROFILE = cfg.profile.name;
    OLLAMA_URL = cfg.services.ollama.url;
    NIXOS_REBUILD_FLAGS = cfg.rebuild.flags;
    # OrbStack forwards the host (macOS) SSH agent via this socket.
    # Setting it here makes it available even in non-SSH sessions.
    SSH_AUTH_SOCK = "/opt/orbstack-guest/run/host-ssh-agent.sock";
  };

  programs.ssh.extraConfig = "
    Host *
      ForwardAgent yes
  ";
}
