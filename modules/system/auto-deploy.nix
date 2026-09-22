{
  config,
  ...
}:

{
  programs.ssh.knownHosts."github.com".publicKey =
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl";

  services.comin = {
    enable = true;
    hostname = config.dotfiles.profile.name;

    remotes = [
      {
        name = "origin";
        url = "git@github.com:joshan-kana/.files.git";

        auth = {
          username = "git";
          ssh_deploy_key_path = "${config.dotfiles.secretsDir}/comin-github";
        };
        branches.testing.name = "";
      }
    ];
  };
}
