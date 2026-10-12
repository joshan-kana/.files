{ lib }:

{
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
