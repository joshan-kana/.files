{
  config,
  lib,
  pkgs,
  ...
}:
let
  command = [
    ""
    "${lib.getExe pkgs.uwsm} aux exec -- %I ${lib.getExe pkgs.wl-restart} -- ${lib.getExe' config.programs.hyprland.package "start-hyprland"} --"
  ];
in
{
  # Keep the Wayland socket alive while start-hyprland handles compositor
  # crashes, safe-mode retries, and clean logout.
  systemd.user.services =
    lib.genAttrs
      [
        "wayland-wm@hyprland.desktop"
        "wayland-wm@hyprland-uwsm.desktop"
      ]
      (_: {
        overrideStrategy = "asDropin";
        serviceConfig.ExecStart = command;
      });

  environment.sessionVariables.QT_WAYLAND_RECONNECT = "1";
}
