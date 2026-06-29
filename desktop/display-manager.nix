{
  config,
  lib,
  pkgs,
  ...
}:
let
  lySessionWrapper = pkgs.writeShellScriptBin "ly-session-wrapper" ''
    if [ "''${XDG_SESSION_TYPE:-}" = "tty" ]; then
      . /etc/profile

      if test -f "$HOME/.profile"; then
        . "$HOME/.profile"
      fi

      cd "$HOME"

      /run/current-system/systemd/bin/systemctl --user import-environment \
        DBUS_SESSION_BUS_ADDRESS \
        XDG_SESSION_ID \
        XDG_SESSION_TYPE \
        XDG_SESSION_CLASS \
        XDG_SEAT \
        XDG_VTNR

      if test "$1"; then
        eval exec "$@"
      else
        echo "error: unknown session $1" 1>&2
        exit 1
      fi
    else
      source ${config.services.displayManager.sessionData.wrapper}
    fi
  '';
in
{
  # Enable display manager
  services.displayManager.ly.enable = true;

  # Backport the Ly shell-session fix:
  # keep Ly's built-in shell attached to the TTY, while preserving normal
  # display-manager logging for graphical sessions.
  services.displayManager.ly.settings.setup_cmd = lib.getExe lySessionWrapper;
}
