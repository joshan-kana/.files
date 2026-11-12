#!/usr/bin/env bash
service=linux-desktop-recording.service
case "${1:-status}" in
status)
  if systemctl --user --quiet is-active "$service"; then echo active; else echo inactive; fi
  ;;
stop)
  state="${XDG_RUNTIME_DIR:?}/linux-desktop-recording.state"
  if systemctl --user --quiet is-active "$service"; then
    if [ -r "$state" ]; then
      { IFS= read -r previous && IFS= read -r started && IFS= read -r savedPath; } <"$state" || true
      if [[ $previous == recording || $previous == finalising ]] && [ -n "${started:-}" ] && [ -n "${savedPath:-}" ]; then
        printf 'finalising\n%s\n%s\n' "$started" "$savedPath" >"$state"
      fi
    fi
    systemctl --user stop "$service"
  fi
  rm -f -- "${XDG_RUNTIME_DIR:?}/linux-desktop-recording.conf"
  ;;
start)
  [ "$#" -eq 4 ] || exit 2
  [[ $2 =~ ^[a-zA-Z0-9_.-]+$ ]] || exit 2
  [[ $3 =~ ^-?[0-9]+,-?[0-9]+\ [0-9]+x[0-9]+$ ]] || exit 2
  case "$4" in none | system | microphone) ;; *) exit 2 ;; esac
  if systemctl --user --quiet is-active "$service"; then exit 3; fi
  umask 077
  config="${XDG_RUNTIME_DIR:?}/linux-desktop-recording.conf"
  temp="$(mktemp "${XDG_RUNTIME_DIR:?}/.linux-desktop-recording.XXXXXXXX")"
  printf '%s\n%s\n%s\n' "$2" "$3" "$4" >"$temp"
  mv -f -- "$temp" "$config"
  state="${XDG_RUNTIME_DIR:?}/linux-desktop-recording.state"
  printf 'starting\n' >"$state"
  if ! systemctl --user start "$service"; then
    rm -f -- "$config"
    exit 1
  fi
  # A queued systemd start is not recorder readiness. Observe the service
  # and recorder-owned state before telling the picker that capture started.
  for _ in {1..25}; do
    if ! systemctl --user --quiet is-active "$service"; then
      sleep 0.1
      continue
    fi
    phase="$(head -n 1 "$state" 2>/dev/null || true)"
    if [ "$phase" = recording ]; then exit 0; fi
    sleep 0.1
  done
  printf 'Recorder did not become active\n' >&2
  exit 1
  ;;
*) exit 2 ;;
esac
