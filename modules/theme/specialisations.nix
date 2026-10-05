{
  lib,
  pkgs,
  ...
}:

let
  themeRegistry = import ./registry.nix { inherit lib pkgs; };

  configurationFor =
    name:
    { config, ... }:
    let
      theme = themeRegistry.resolve name;
      inherit (theme) assets;
    in
    {
      stylix = {
        image = lib.mkForce assets.wallpaper;
        fonts = lib.mkForce theme.fonts;
        polarity = lib.mkForce theme.polarity;
        cursor = lib.mkForce assets.cursor;
        base16Scheme = lib.mkForce (
          if theme ? colors then
            {
              system = "base16";
              name = theme.label;
              variant = theme.polarity;
              palette = theme.colors;
            }
          else
            config.stylix.generated.palette
        );
      };

      home-manager.sharedModules = [
        {
          gtk.iconTheme = lib.mkForce assets.icons;
        }
      ];
    };

in
{
  specialisation = lib.mapAttrs (name: _: {
    configuration = configurationFor name;
  }) themeRegistry.variants;
}
