#!/usr/bin/env bash
case "${1:-}" in
logout | reboot | poweroff)
  case "${2:-fresh}" in
  restore)
    if ! hypr-persist save last; then
      notify-send -u critical "Session not saved" "Windows were not saved, so the session was not ended." || true
      exit 1
    fi
    ;;
  fresh)
    # A saved layout can remain available for manual restore;
    # cancel only the one-shot request before exiting.
    rm -f -- "${XDG_DATA_HOME:-$HOME/.local/share}/hypr-persist/sessions/.restore-next"
    ;;
  *)
    printf 'Expected restore or fresh session mode.\n' >&2
    exit 2
    ;;
  esac
  ;;
esac
case "${1:-}" in
suspend) exec systemctl suspend ;;
logout) exec uwsm stop ;;
reboot) exec systemctl reboot ;;
poweroff) exec systemctl poweroff ;;
*)
  printf 'Usage: linux-desktop-session {suspend|logout|reboot|poweroff} [restore|fresh]\n' >&2
  exit 2
  ;;
esac
