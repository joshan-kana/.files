{
  config,
  lib,
  pkgs,
  ...
}:

let
  cominFetch = pkgs.writeShellScript "comin-fetch" ''
    exec ${lib.getExe config.services.comin.package} fetch
  '';
in
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

        # Events are the fast path. Polling remains reconciliation.
        poller.period = 300;
      }
    ];
  };

  webhook =
    _:

    let
      topic = "${config.dotfiles.services.ntfy.url}/comin";
      handleEvent = pkgs.writeShellScript "comin-event" ''
        [ "''${NTFY_MESSAGE:-}" = "fetch" ] || exit 0
        exec ${cominFetch}
      '';
    in
    {
      systemd.services.comin-event-listener = {
        description = "Trigger Comin from ntfy events";
        after = [ "network-online.target" ];
        wants = [ "network-online.target" ];
        wantedBy = [ "multi-user.target" ];

        script = ''
          exec ${lib.getExe pkgs.ntfy-sh} subscribe \
            ${lib.escapeShellArg topic} \
            ${handleEvent}
        '';

        serviceConfig = {
          Restart = "always";
          RestartSec = "5s";
        };
      };
    };
}
