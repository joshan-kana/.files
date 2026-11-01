{ lib }:

{
  desktop.default.boot = {
    plymouth.enable = true;
    kernelParams = [
      "quiet"
      "systemd.show_status=1"
    ];
  };
  desktop.arm.dotfiles.scopes.desktopApps =
    lib.genAttrs
      [
        "spotify"
        "discord"
        "dropbox"
        "onlyoffice"
        "twingate"
      ]
      (_: {
        enable = lib.mkDefault false;
      });
}
