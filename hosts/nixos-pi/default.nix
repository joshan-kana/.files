{
  editScope,
  extendScope,
  lib,
  moduleRegistry,
  ...
}:

lib.recursiveUpdate (import ../../profiles/media.nix { inherit lib moduleRegistry; }) {
  hardware = import ./hardware.nix;

  dotfiles.scopes = {
    system.boot.loader.enable = false;
    desktopApps = {
      moonlight.enable = false;
      moonlightRpi.enable = true;
    };
  };

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

  cli = editScope moduleRegistry.cli {
    mpv = _: {
      home = { lib, pkgs, ... }: {
        programs.mpv = {
          enable = true;
          package = pkgs.mpv-rpi;
          # Keep the validated hardware player free of extra scripts.
          scripts = lib.mkForce [ ];
          config = {
            target-colorspace-hint = lib.mkForce "no";
            input-commands-append = lib.mkForce [ ];
            vo = "dmabuf-wayland,gpu";
            hwdec = "drm,v4l2m2m";
            hwdec-threads = 2;
            hwdec-extra-frames = 0;
            vd-queue-enable = false;
          };
          # The SDR DMA-BUF output does not support the shared HDR profiles.
          profiles = lib.mkForce { };
        };
      };
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

  desktopApps =
    extendScope
      (editScope moduleRegistry.desktopApps {
        kodi = _: {
          home = { config, lib, ... }: {
            home.file.".kodi/userdata/playercorefactory.xml".text = ''
              <playercorefactory>
                <players>
                  <player name="MPV" type="ExternalPlayer" audio="false" video="true">
                    <filename>${lib.getExe config.programs.mpv.finalPackage}</filename>
                    <args>--fullscreen "{1}"</args>
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
        jellyfin = _: {
          home = { config, lib, ... }: {
            services.jellyfin-mpv-shim.settings = {
              mpv_ext = true;
              mpv_ext_path = lib.getExe config.programs.mpv.finalPackage;
            };
            systemd.user.services.jellyfin-mpv-shim.Install.WantedBy = lib.mkForce [
              "graphical-session.target"
            ];
          };
        };
      })
      {
        # Home Manager merges package lists, so replace only the Moonlight scope.
        moonlightRpi = _: {
          home = { pkgs, ... }: {
            home.packages = [ pkgs.moonlight-qt-rpi ];
          };
        };
      };
}
