{ pkgs, ... }:

{
  users.groups.herdr-worker = { };
  users.users.herdr-worker = {
    isSystemUser = true;
    group = "herdr-worker";
    home = "/var/lib/herdr-worker";
    createHome = true;
    shell = pkgs.bashInteractive;
    # Grant the machine owner access to the unprivileged Herdr runtime over SSH.
    # No PTY, port-forwarding, agent-forwarding, or X11 forwarding is permitted.
    openssh.authorizedKeys.keys = [
      "restrict ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGMZdbT05P/naiv07J32DxHDOR5A1z8F9jijeBrDkXWV joshankana@gmail.com"
    ];
  };

  security.polkit.extraConfig = ''
    polkit.addRule(function(action, subject) {
      if (subject.user === "herdr-worker")
        return polkit.Result.NO;
    });
  '';

  systemd.services.herdr-worker-core = {
    description = "Persistent Herdr terminal runtime for restricted agent sessions";
    wantedBy = [ "multi-user.target" ];
    path = with pkgs; [
      bashInteractive
      coreutils
      git
      herdr-core
      openssh
      procps
    ];
    environment = {
      HOME = "/var/lib/herdr-worker";
      HC_SESSION = "chatgpt-shell";
      XDG_CONFIG_HOME = "/var/lib/herdr-worker/.config";
      XDG_RUNTIME_DIR = "/run/herdr-worker";
      XDG_STATE_HOME = "/var/lib/herdr-worker/.local/state";
    };
    serviceConfig = {
      Type = "simple";
      User = "herdr-worker";
      Group = "herdr-worker";
      ExecStart = "${pkgs.herdr-core}/bin/herdr-core serve";
      Restart = "on-failure";
      RestartSec = "2s";
      RuntimeDirectory = "herdr-worker";
      RuntimeDirectoryMode = "0700";
      StateDirectory = "herdr-worker";
      StateDirectoryMode = "0700";
      UMask = "0077";
      NoNewPrivileges = true;
      ProtectSystem = "strict";
      ProtectHome = true;
      PrivateTmp = true;
    };
  };
}
