{
  config,
  configurationFlakeSubdirectory,
  configurationOutputName,
  lib,
  pkgs,
  system,
  ...
}:

let
  inherit (lib.systems.elaborate system) isDarwin isLinux;
in
{
  programs.ssh.knownHosts."github.com".publicKey =
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl";

  services.comin = {
    enable = true;
    hostname = configurationOutputName;
    allowForcePush = true;

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
  }
  // lib.optionalAttrs (configurationFlakeSubdirectory != null) {
    repositorySubdir = configurationFlakeSubdirectory;
  };

  home = _: {
    home.shellAliases = {
      cw = "comin watch";
      ce = "comin deployment submit-latest";
    };
  };

  startup =
    _:
    let
      delaySeconds = 30;
    in
    lib.optionalAttrs isLinux {
      systemd.services.comin-startup-fetch = {
        description = "Fetch Comin updates after boot";
        after = [ "comin.service" ];
        serviceConfig = {
          Type = "oneshot";
          ExecStart = "${lib.getExe config.services.comin.package} fetch";
        };
      };

      systemd.timers.comin-startup-fetch = {
        wantedBy = [ "timers.target" ];
        timerConfig.OnBootSec = "${toString delaySeconds}s";
      };
    }
    // lib.optionalAttrs isDarwin {
      launchd.daemons.comin-startup-fetch.serviceConfig = {
        ProgramArguments = [
          "/bin/sh"
          "-c"
          "/bin/wait4path /nix/store && /bin/sleep ${toString delaySeconds} && exec ${lib.getExe config.services.comin.package} fetch"
        ];
        RunAtLoad = true;
        StandardOutPath = "/var/log/comin-startup-fetch.log";
        StandardErrorPath = "/var/log/comin-startup-fetch.log";
      };
    };

  webhook =
    _:

    let
      topic = "${config.dotfiles.services.ntfy.url}/comin";
    in
    {
      config = lib.optionalAttrs isLinux {
        systemd.services.comin-event-listener = {
          description = "Trigger Comin from ntfy events";
          wantedBy = [ "multi-user.target" ];

          script = ''
            exec ${lib.getExe pkgs.ntfy-sh} subscribe \
              ${lib.escapeShellArg topic} \
              ${lib.escapeShellArg "${lib.getExe config.services.comin.package} fetch"}
          '';

          serviceConfig = {
            Restart = "on-failure";
            RestartSec = "5s";
          };
        };
      };
    }
    // lib.optionalAttrs isDarwin {
      launchd.daemons.comin-event-listener.serviceConfig = {
        ProgramArguments = [
          "/bin/sh"
          "-c"
          ''
            /bin/wait4path /nix/store && exec ${lib.getExe pkgs.ntfy-sh} subscribe \
              ${lib.escapeShellArg topic} \
              ${lib.escapeShellArg "${lib.getExe config.services.comin.package} fetch"}
          ''
        ];
        RunAtLoad = true;
        KeepAlive = true;
        ThrottleInterval = 5;
        StandardOutPath = "/var/log/comin-event-listener.log";
        StandardErrorPath = "/var/log/comin-event-listener.log";
      };
    };
}
