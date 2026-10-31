{ lib }:

let
  desktop = {
    boot.plymouth.enable = true;
  };
in
{
  desktop = {
    default = desktop;
    arm = {
      imports = [ desktop ];
      dotfiles.scopes.desktopApps =
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
    };
  };
}
