{
  config,
  lib,
  pkgs,
  system,
  ...
}:

let
  inherit (lib.systems.elaborate system) isDarwin;
  luaFiles = builtins.filter (name: lib.hasSuffix ".lua" name) (
    builtins.attrNames (builtins.readDir ./files)
  );
  colors = config.lib.stylix.colors;
  palette = {
    bg = colors.base00;
    bgAlt = colors.base01;
    bgSelected = colors.base02;
    stroke = colors.base03;
    fg = colors.base05;
    fgDim = colors.base04;
    fgMuted = colors.base03;
    accent = colors.base08;
    green = colors.base0B;
    yellow = colors.base0A;
    blue = colors.base0D;
    magenta = colors.base0E;
    cyan = colors.base0C;
  };
  paletteLua = lib.concatStringsSep "\n" (
    lib.mapAttrsToList (name: hex: "  ${name} = { hex = \"${hex}\" },") palette
  );
in
{
  home = _: {
    home.file =
      lib.listToAttrs (
        map (name: {
          name = ".hammerspoon/${name}";
          value.source = ./files + "/${name}";
        }) luaFiles
      )
      // {
        ".hammerspoon/stylix_palette.lua".text = ''
          return {
          ${paletteLua}
          }
        '';
      };
  };
}
// lib.optionalAttrs isDarwin {
  environment.systemPackages = [ pkgs.hammerspoon ];
}
