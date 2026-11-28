{
  editScope,
  extendScope,
  lib,
  moduleRegistry,
  ...
}:

lib.recursiveUpdate (import ../../profiles/media.nix { inherit lib moduleRegistry; }) {
  hardware = import ./hardware.nix;

  dotfiles.scopes.system.boot.loader.enable = false;

  system = editScope moduleRegistry.system {
    identity = { config, ... }: {
      users.users.${config.dotfiles.users.primary.name}.uid = 1000;
    };
    privilegeSshAgent = _: {
      systemd.tmpfiles.rules = [
        "f+ /etc/elevation-authorized-key 0444 root root - ${
          lib.concatStringsSep "\\n" (
            map (lib.replaceStrings [ " " ] [ "\\x20" ]) [
              "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEBfBg52XAZkpWk2cKNqvITRhsrnmEdz8yon5bpZZP/w joshan@nixos-pi-sudo"
              "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMgQFxMmgs5HwY+l9twQBUEt672VOFrmgAnOKuoMuzz/ nixos-pi-sudo"
            ]
          )
        }\\n"
      ];
    };
  };

  networking = editScope moduleRegistry.networking {
    ssh = { config, ... }: {
      users.users.${config.dotfiles.users.primary.name}.openssh.authorizedKeys.keys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGMZdbT05P/naiv07J32DxHDOR5A1z8F9jijeBrDkXWV joshankana@gmail.com"
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBU9mnHy1HP+StbXl3HmTSpOVJ1VETv9DYWUj1YmzDKc chatgpt-shell-nixos-pi"
      ];
    };
  };

  audio = extendScope moduleRegistry.audio {
    hdmi = _: {
      services.pipewire.wireplumber.extraConfig."51-hdmi-preferred"."monitor.alsa.rules" = [
        {
          matches = [ { "node.name" = "~alsa_output.platform-.*\\.hdmi\\..*"; } ];
          actions.update-props."priority.session" = 1500;
        }
      ];
    };
  };

  cli = editScope moduleRegistry.cli {
    mpv = { lib, ... }: {
      nixpkgs.overlays = lib.mkAfter [ (_: prev: { mpv = prev.mpv-rpi; }) ];
    };
  };

  desktop = editScope moduleRegistry.desktop {
    mediaSession = _: {
      home = _: {
        programs.mpv.config = {
          target-colorspace-hint = lib.mkForce "no";
          vo = "dmabuf-wayland,gpu";
          hwdec = "drm,v4l2m2m";
          hwdec-threads = 2;
          hwdec-extra-frames = 0;
          vd-queue-enable = false;
        };
      };
    };
  };

  desktopApps = editScope moduleRegistry.desktopApps {
    moonlight = { lib, ... }: {
      nixpkgs.overlays = lib.mkAfter [ (_: prev: { moonlight-qt = prev.moonlight-qt-rpi; }) ];
    };
    kodi = { lib, ... }: {
      nixpkgs.overlays = lib.mkAfter [ (_: prev: { kodi = prev.kodi-gbm-rpi; }) ];
      home = _: {
        home.file.".kodi/userdata/advancedsettings.xml".text = ''
          <advancedsettings>
            <videoplayer>
              <useprimedecoder>true</useprimedecoder>
              <useprimedecoderforhw>true</useprimedecoderforhw>
              <useprimerenderer>0</useprimerenderer>
            </videoplayer>
            <videoscreen>
              <limitguisize>3</limitguisize>
            </videoscreen>
          </advancedsettings>
        '';
      };
    };
    jellyfin = _: {
      home = { config, lib, ... }: {
        services.jellyfin-mpv-shim.settings = {
          mpv_ext = true;
          mpv_ext_path = lib.getExe config.programs.mpv.finalPackage;
        };
        systemd.user.services.jellyfin-mpv-shim.Install.WantedBy = lib.mkForce [
          "graphical-session.target"
        ];
        home.activation.stopJellyfinMpvShim =
          lib.hm.dag.entryBetween [ "jellyfinMpvShimSettingsActivation" ] [ "writeBoundary" ]
            ''
              jellyfinWasActive=false
              if env XDG_RUNTIME_DIR="''${XDG_RUNTIME_DIR:-/run/user/$(id -u)}" ${config.systemd.user.systemctlPath} --user is-active --quiet jellyfin-mpv-shim.service; then
                jellyfinWasActive=true
                run env XDG_RUNTIME_DIR="''${XDG_RUNTIME_DIR:-/run/user/$(id -u)}" ${config.systemd.user.systemctlPath} --user stop jellyfin-mpv-shim.service
              fi
            '';
        home.activation.restartJellyfinMpvShim = lib.hm.dag.entryAfter [ "reloadSystemd" ] ''
          if [ "$jellyfinWasActive" = true ] && env XDG_RUNTIME_DIR="''${XDG_RUNTIME_DIR:-/run/user/$(id -u)}" ${config.systemd.user.systemctlPath} --user is-active --quiet graphical-session.target; then
            run env XDG_RUNTIME_DIR="''${XDG_RUNTIME_DIR:-/run/user/$(id -u)}" ${config.systemd.user.systemctlPath} --user start jellyfin-mpv-shim.service
          fi
        '';
      };
    };
  };
}
