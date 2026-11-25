{
  config,
  lib,
  pkgs,
  ...
}:

let
  session = pkgs.writeShellScript "media-session" ''
    export XDG_SESSION_TYPE=wayland
    export XDG_CURRENT_DESKTOP=labwc
    ${lib.getExe pkgs.labwc}
    status=$?
    systemctl --user stop labwc-session.target
    exit "$status"
  '';
in
{
  hardware.graphics.enable = true;
  environment.systemPackages = [
    pkgs.wlr-randr
  ];
  services.greetd = {
    enable = true;
    useTextGreeter = true;
    settings = {
      initial_session = {
        command = "${session}";
        user = config.dotfiles.users.primary.name;
      };
      default_session.command = "${pkgs.greetd}/bin/agreety --cmd ${session}";
    };
  };

  home =
    { config, osConfig, ... }:
    let
      launcher = pkgs.flex-launcher;
      icons = "${launcher}/share/flex-launcher/assets/icons";
      launcherConfig = ''
        [General]
        DefaultMenu=Home
        OnLaunch=None
        MouseSelect=true

        [Layout]
        MaxButtons=5
        IconSize=180

        [Titles]
        Font=${launcher}/share/flex-launcher/assets/fonts/OpenSans-Regular.ttf

        [Highlight]
        CornerRadius=18

        [Gamepad]
        Enabled=true
        ButtonA=:select
        ButtonB=:back
        ButtonDPadLeft=:left
        ButtonDPadRight=:right

        [Home]
        Entry1=Kodi;${icons}/kodi.png;kodi
        Entry2=Browser;${config.home.profileDirectory}/share/icons/hicolor/128x128/apps/chromium.png;${osConfig.dotfiles.defaults.browser} --start-maximized
        Entry3=Moonlight;${config.home.profileDirectory}/share/icons/hicolor/scalable/apps/moonlight.svg;moonlight
        Entry4=Phone pairing;${icons}/system.png;kdeconnect-app
        Entry5=Power;${icons}/restart.png;:submenu Power

        [Power]
        Entry1=Shutdown;${icons}/system.png;:shutdown
        Entry2=Restart;${icons}/restart.png;:restart
        Entry3=Back;${icons}/sleep.png;:back
      '';
    in
    {
      xdg.configFile."flex-launcher/config.ini".text = launcherConfig;
      wayland.windowManager.labwc = {
        enable = true;
      };

      systemd.user.services.media-launcher = {
        Unit = {
          Description = "Television application launcher";
          PartOf = [ "labwc-session.target" ];
          After = [ "graphical-session-pre.target" ];
        };
        Service = {
          ExecStart = "${lib.getExe launcher} -c ${config.xdg.configHome}/flex-launcher/config.ini";
          Restart = "always";
          RestartSec = 1;
        };
        Install.WantedBy = [ "labwc-session.target" ];
      };

      # HDMI hotplug can make WayVNC exit successfully with no remaining outputs.
      systemd.user.services.wayvnc.Service = {
        Restart = "always";
        RestartSec = 5;
      };

      services.wayvnc = {
        enable = true;
        autoStart = true;
        systemdTarget = "labwc-session.target";
        settings = {
          address = "127.0.0.1";
          port = 5900;
        };
      };
    };
}
