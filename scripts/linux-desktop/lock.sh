#!/usr/bin/env bash
# Hide notification content before the asynchronous lock compositor
# handshake begins. The lock shell releases this marker only after
# successfully authenticated unlock.
marker="${XDG_RUNTIME_DIR:?}/linux-desktop-session-lock.state"
temp="$(mktemp "${marker}.XXXXXX")"
trap 'rm -f -- "$temp"' EXIT
printf 'requested\n' >"$temp"
chmod 600 "$temp"
mv -f -- "$temp" "$marker"
systemctl --user start linux-desktop-lock.service
