{ lib }:

let
  disabledChildren = path: lib.mapAttrs (_: _: { enable = lib.mkDefault false; }) (import path);
in
{
  # Platform profiles disable unsupported native children without removing
  # them from the shared registry or changing their default enable state.
  linux = {
    core.dotfiles.scopes = {
      cli = disabledChildren ../cli/darwin.nix;
      virtualisation = disabledChildren ../virtualisation/darwin.nix;
    };
    desktop.dotfiles.scopes = {
      desktopApps = disabledChildren ../desktop-apps/darwin.nix;
      desktop = disabledChildren ../desktop/darwin.nix;
    };
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
