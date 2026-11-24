#!/usr/bin/env bash
service=desktop-shell-recording.service
case "${1:-status}" in
status)
  if systemctl --user --quiet is-active "$service"; then echo active; else echo inactive; fi
  ;;
stop)
  state="${XDG_RUNTIME_DIR:?}/desktop-shell-recording.state"
  if systemctl --user --quiet is-active "$service"; then
    if [ -r "$state" ]; then
      { IFS= read -r previous && IFS= read -r started && IFS= read -r savedPath; } <"$state" || true
      if [[ $previous == recording || $previous == finalising ]] && [ -n "${started:-}" ] && [ -n "${savedPath:-}" ]; then
        printf 'finalising\n%s\n%s\n' "$started" "$savedPath" >"$state"
      fi
    fi
    systemctl --user stop "$service"
  fi
  rm -f -- "${XDG_RUNTIME_DIR:?}/desktop-shell-recording.conf"
  ;;
start)
  [ "$#" -eq 4 ] || [ "$#" -eq 8 ] || exit 2
  [[ $2 =~ ^[a-zA-Z0-9_.-]+$ ]] || exit 2
  [[ $3 =~ ^-?[0-9]+,-?[0-9]+\ [0-9]+x[0-9]+$ ]] || exit 2
  case "$4" in none | system | microphone) ;; *) exit 2 ;; esac
  format="${5:-mp4}"
  codec="${6:-libx264}"
  fps="${7:-0}"
  quality="${8:-23}"
  case "$format" in mp4 | mkv) ;; *) exit 2 ;; esac
  case "$codec" in libx264 | libx265) ;; *) exit 2 ;; esac
  case "$fps" in 0 | 30 | 60 | 120) ;; *) exit 2 ;; esac
  case "$quality" in 18 | 23 | 28) ;; *) exit 2 ;; esac
  if systemctl --user --quiet is-active "$service"; then exit 3; fi
  umask 077
  config="${XDG_RUNTIME_DIR:?}/desktop-shell-recording.conf"
  temp="$(mktemp "${XDG_RUNTIME_DIR:?}/.desktop-shell-recording.XXXXXXXX")"
  printf '%s\n' "$2" "$3" "$4" "$format" "$codec" "$fps" "$quality" >"$temp"
  mv -f -- "$temp" "$config"
  state="${XDG_RUNTIME_DIR:?}/desktop-shell-recording.state"
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
    if [ "$phase" = recording ]; then
      saved="$(tail -n 1 "$state" 2>/dev/null || true)"
      # The wrapper sets its phase before starting the encoder. A live
      # service alone is not proof that the recording file was opened.
      if [ -s "$saved" ] && [ ! -L "$saved" ] && systemctl --user --quiet is-active "$service"; then
        exit 0
      fi
    fi
    sleep 0.1
  done
  printf 'Recorder did not become active\n' >&2
  exit 1
  ;;
*) exit 2 ;;
esac
