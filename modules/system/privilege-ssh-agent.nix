{ pkgs, ... }:

let
  verify = pkgs.writeScriptBin "run0-ssh-agent-verify" ''
    #!${pkgs.python3}/bin/python3
    import os
    import pwd
    import stat
    import subprocess
    import sys

    def authorised():
        try:
            request = sys.stdin.buffer.readline(32).decode("ascii").strip()
            if not request.isdecimal():
                return False
            pid = int(request)
            uid = pwd.getpwnam("joshan").pw_uid
            if pid <= 1:
                return False

            # Keep /proc bound to the original process across PID reuse.
            proc = os.open(f"/proc/{pid}", os.O_RDONLY | os.O_DIRECTORY | os.O_CLOEXEC)
            try:
                status_fd = os.open("status", os.O_RDONLY, dir_fd=proc)
                with os.fdopen(status_fd, "rb") as f:
                    ids = next(line for line in f if line.startswith(b"Uid:"))
                if any(int(n) != uid for n in ids.split()[1:5]):
                    return False
                environ_fd = os.open("environ", os.O_RDONLY, dir_fd=proc)
                with os.fdopen(environ_fd, "rb") as f:
                    values = f.read(1024 * 1024).split(b"\0")
            finally:
                os.close(proc)

            sockets = [item[len(b"SSH_AUTH_SOCK="):] for item in values
                       if item.startswith(b"SSH_AUTH_SOCK=")]
            if len(sockets) != 1:
                return False
            agent = os.fsdecode(sockets[0])
            if not agent.startswith("/") or not stat.S_ISSOCK(os.stat(agent).st_mode):
                return False
            if os.stat(agent).st_uid != uid:
                return False
            # ssh-add -T checks a real, fresh SSH signature for the allowlisted key.
            return subprocess.run(
                ["${pkgs.openssh}/bin/ssh-add", "-T", "/etc/elevation-authorized-key"],
                env={"SSH_AUTH_SOCK": agent}, stdin=subprocess.DEVNULL,
                stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                timeout=6, check=False,
            ).returncode == 0
        except (OSError, ValueError, StopIteration, subprocess.TimeoutExpired, UnicodeError):
            return False

    print("ALLOW" if authorised() else "DENY", flush=True)
  '';
  request = pkgs.writeShellScriptBin "run0-ssh-agent-request" ''
    if [[ ! "$1" =~ ^[0-9]+$ ]]; then
      exit 1
    fi
    printf '%s\n' "$1" | ${pkgs.socat}/bin/socat - UNIX-CONNECT:/run/run0-ssh-agent-auth.sock
  '';
in
{
  security.polkit.extraConfig = ''
    polkit.addRule(function(action, subject) {
      if (action.id !== "org.freedesktop.systemd1.manage-units" ||
          subject.user !== "joshan" || !subject.isInGroup("wheel"))
        return;
      // StartTransientUnit does not consistently provide unit/verb details.
      // SSH signature verification is required for every matched operation.
      if (typeof subject.pid !== "number" || subject.pid <= 1)
        return;
      try {
        if (polkit.spawn(["${request}/bin/run0-ssh-agent-request", String(subject.pid)]).trim() === "ALLOW")
          return polkit.Result.YES;
      } catch (e) {
        polkit.log("run0 SSH-agent verification unavailable: " + e);
      }
    });
  '';

  systemd.sockets.run0-ssh-agent-auth = {
    wantedBy = [ "sockets.target" ];
    socketConfig = {
      ListenStream = "/run/run0-ssh-agent-auth.sock";
      SocketUser = "root";
      SocketGroup = "polkituser";
      SocketMode = "0660";
      Accept = true;
    };
  };
  systemd.services."run0-ssh-agent-auth@" = {
    description = "Verify an SSH-agent signature for a run0 Polkit request";
    serviceConfig = {
      ExecStart = "${verify}/bin/run0-ssh-agent-verify";
      StandardInput = "socket";
      StandardOutput = "socket";
      NoNewPrivileges = true;
      ProtectSystem = "strict";
      ProtectHome = "read-only";
      # SSH forwarding may put its socket below /tmp.
      PrivateTmp = false;
      RestrictAddressFamilies = "AF_UNIX";
    };
  };
}
