{
  configuration,
  imageConfiguration,
  configurations,
}:

let
  inherit (configuration.pkgs) lib;
  cfg = configuration.config;
  image = imageConfiguration.config;
  home = cfg.home-manager.users.${cfg.dotfiles.users.primary.name};
in
assert lib.all (
  host:
  lib.all (path: !(lib.attrByPath (path ++ [ "enable" ]) false host.config.dotfiles.resolvedScopes)) [
    [
      "desktop"
      "mediaSession"
    ]
    [
      "desktopApps"
      "kodi"
    ]
    [
      "desktopApps"
      "kdeConnect"
    ]
    [
      "desktopApps"
      "librespot"
    ]
  ]
) (lib.attrValues (builtins.removeAttrs configurations [ "nixos-pi" ]));
assert cfg.services.greetd.enable;
assert !cfg.services.desktopManager.plasma6.enable;
assert !cfg.programs.hyprland.enable;
assert !cfg.services.xserver.enable;
assert cfg.hardware.graphics.enable;
assert cfg.services.pipewire.enable;
assert home.wayland.windowManager.labwc.enable;
assert home.services.kdeconnect.enable;
assert home.services.librespot.enable;
assert home.services.wayvnc.settings.address == "127.0.0.1";
assert
  home.xdg.mimeApps.defaultApplications."x-scheme-handler/https" == [ "chromium-browser.desktop" ];
assert home.systemd.user.services.media-launcher.Install.WantedBy == [ "labwc-session.target" ];
assert
  home.systemd.user.services.jellyfin-mpv-shim.Install.WantedBy == [ "graphical-session.target" ];
assert builtins.elem "pcie-brcmstb" cfg.boot.initrd.availableKernelModules;
assert builtins.elem "pcie-brcmstb" image.boot.initrd.availableKernelModules;
assert cfg.hardware.raspberry-pi.firmware.enable;
assert cfg.hardware.raspberry-pi.firmware.path == "/boot";
assert !cfg.boot.loader.generic-extlinux-compatible.useGenerationDeviceTree;
assert cfg.boot.kernelPackages.kernel.pname == "linux-rpi";
assert builtins.elem "reset-raspberrypi" cfg.boot.initrd.availableKernelModules;
assert image.services.greetd.enable;
assert lib.hasInfix "install-rpi-firmware" image.sdImage.populateFirmwareCommands;
assert lib.hasInfix "-d ./firmware" image.sdImage.populateFirmwareCommands;
true
