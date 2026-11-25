{
  editScope,
  lib,
  moduleRegistry,
  ...
}:

let
  profile = import ../../profiles/media.nix { inherit editScope lib moduleRegistry; };
in
lib.recursiveUpdate profile {
  hardware = import ./hardware.nix;

  audio =
    {
      lib,
      pkgs,
      system,
      ...
    }:
    lib.recursiveUpdate (moduleRegistry.audio { inherit lib pkgs system; }) {
      services.pipewire.wireplumber.extraConfig."51-hdmi-preferred"."monitor.alsa.rules" = [
        {
          matches = [ { "node.name" = "~alsa_output.platform-.*\\.hdmi\\..*"; } ];
          actions.update-props."priority.session" = 1500;
        }
      ];
    };

  desktop = editScope profile.desktop {
    mediaSession = _: {
      home = _: {
        wayland.windowManager.labwc = {
          environment = [ "WLR_RENDERER=vulkan" ];
          rc.core.hdr = "yes";
        };
      };
    };
  };

  desktopApps = editScope profile.desktopApps {
    kodi = _: {
      home = { config, pkgs, ... }: {
        home.file.".kodi/userdata/playercorefactory.xml".text = ''
          <playercorefactory>
            <players>
              <player name="MPV" type="ExternalPlayer" audio="false" video="true">
                <filename>${lib.getExe pkgs.mpv-rpi}</filename>
                <args>--no-config --include="${config.xdg.configHome}/jellyfin-mpv-shim/mpv.conf" --fullscreen "{1}"</args>
                <hidexbmc>true</hidexbmc>
              </player>
            </players>
            <rules action="prepend">
              <rule video="true" filetypes="mkv|mp4|m4v|mov|webm|avi|ts|m2ts" player="MPV"/>
            </rules>
          </playercorefactory>
        '';
      };
    };
    moonlight = _: {
      nixpkgs.overlays = lib.mkAfter [
        (_final: prev: { moonlight-qt = prev.moonlight-qt-rpi; })
      ];
    };
    jellyfin = _: {
      home = { pkgs, ... }: {
        services.jellyfin-mpv-shim.settings = {
          mpv_ext = true;
          mpv_ext_path = lib.getExe pkgs.mpv-rpi;
        };
        xdg.configFile."jellyfin-mpv-shim/mpv.conf".text = ''
          vo=dmabuf-wayland,gpu
          hwdec=drm,v4l2m2m
          hwdec-threads=2
          hwdec-extra-frames=0
          vd-queue-enable=no
        '';
      };
    };
  };

  dotfiles.scopes.system.boot.loader.enable = false;

  system = editScope moduleRegistry.system {
    identity = { config, ... }: {
      users.users.${config.dotfiles.users.primary.name}.uid = 1000;
    };
    privilegeSshAgent = _: {
      systemd.tmpfiles.rules = [
        "f+ /etc/elevation-authorized-key 0444 root root - ${
          lib.concatStringsSep "\\n" [
            "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEBfBg52XAZkpWk2cKNqvITRhsrnmEdz8yon5bpZZP/w joshan@nixos-pi-sudo"
            "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMgQFxMmgs5HwY+l9twQBUEt672VOFrmgAnOKuoMuzz/ nixos-pi-sudo"
          ]
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
}
