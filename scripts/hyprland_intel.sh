#!/usr/bin/env sh
export WLR_DRM_DEVICES=/dev/dri/card1
exec uwsm start hyprland.desktop
