{ pkgs, ... }:
{
  home = _: {
    home.packages = [ pkgs.hypr-persist ];

    xdg.configFile."hypr/hypr-persist.toml".text = ''
      [general]
      save_interval = 120
      restore_on_start = true
      per_window_launch = true
      restore_geometry = true
      restore_layout = true

      [rules]
      exclude = [
        "^xdg-desktop-portal.*",
        "^org\\.kde\\.polkit.*",
        "^polkit-.*",
      ]
    '';

    wayland.windowManager.hyprland.settings.config.dwindle.preserve_split = true;

    systemd.user.services.hypr-persist = {
      Unit = {
        Description = "Save and restore Hyprland sessions";
        ConditionEnvironment = "XDG_CURRENT_DESKTOP=Hyprland";
        After = [ "graphical-session.target" ];
        PartOf = [ "graphical-session.target" ];
      };
      Service = {
        ExecStart = "${pkgs.hypr-persist}/bin/hypr-persist";
        Restart = "on-failure";
        RestartSec = 3;
      };
      Install.WantedBy = [ "graphical-session.target" ];
    };
  };
}
