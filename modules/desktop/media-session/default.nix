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
    ${lib.getExe' pkgs.systemd "systemd-cat"} --identifier=labwc ${lib.getExe pkgs.labwc}
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
      browser = osConfig.dotfiles.defaults.browser;
      hasProgram =
        name: lib.any (package: (package.meta.mainProgram or null) == name) config.home.packages;
      entries =
        lib.optional (hasProgram "kodi") "Kodi;${icons}/kodi.png;kodi"
        ++ lib.optional config.services.jellyfin-mpv-shim.enable "Jellyfin;${config.services.jellyfin-mpv-shim.package}/share/icons/hicolor/256x256/apps/com.github.iwalton3.jellyfin-mpv-shim.png;jellyfin-mpv-shim"
        ++ lib.optional (hasProgram browser) "Browser;${pkgs.adwaita-icon-theme}/share/icons/Adwaita/symbolic/legacy/web-browser-symbolic.svg;${browser}"
        ++ lib.optional (hasProgram "moonlight") "Moonlight;${config.home.profileDirectory}/share/icons/hicolor/scalable/apps/moonlight.svg;moonlight"
        ++ lib.optional config.services.kdeconnect.enable "Phone pairing;${icons}/system.png;kdeconnect-app"
        ++ [ "Power;${icons}/restart.png;:submenu Power" ];
      launcherConfig = ''
        [General]
        DefaultMenu=Home
        OnLaunch=None
        MouseSelect=true

        [Layout]
        MaxButtons=6
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
        ${lib.concatStringsSep "\n" (lib.imap1 (index: entry: "Entry${toString index}=${entry}") entries)}

        [Power]
        Entry1=Shutdown;${icons}/system.png;:shutdown
        Entry2=Restart;${icons}/restart.png;:restart
        Entry3=Back;${icons}/sleep.png;:back
      '';
    in
    {
      xdg.configFile."flex-launcher/config.ini".text = launcherConfig;
      wayland.windowManager.labwc.enable = true;

      # Keep the cast receiver available without covering the home launcher.
      services.jellyfin-mpv-shim.settings = lib.mkIf config.services.jellyfin-mpv-shim.enable {
        start_minimized = true;
        allow_background = true;
        fullscreen = true;
        browser_fullscreen = true;
      };

      systemd.user.services.media-launcher = {
        Unit = {
          Description = "Television application launcher";
          PartOf = [ "labwc-session.target" ];
          After = [ "graphical-session-pre.target" ];
        };
        Service = {
          ExecStart = "${lib.getExe launcher} -c ${config.xdg.configFile."flex-launcher/config.ini".source}";
          Restart = "always";
          Environment = "SDL_VIDEO_DRIVER=wayland";
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
