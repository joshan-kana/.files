{
  lib,
  pkgs,
  ...
}:

let
  luaFiles = builtins.filter (name: lib.hasSuffix ".lua" name) (
    builtins.attrNames (builtins.readDir ./files)
  );
  configHash = builtins.hashString "sha256" (
    lib.concatMapStringsSep "\n" (name: "${name}\n${builtins.readFile (./files + "/${name}")}") luaFiles
  );
in
{
  home =
    { config, osConfig, ... }:
    let
      colors = config.lib.stylix.colors.withHashtag;
      runtime = ''
        return {
          yabai = ${builtins.toJSON (lib.getExe osConfig.services.yabai.package)},
          colors = {
            bg = ${builtins.toJSON colors.base00},
            bgAlt = ${builtins.toJSON colors.base01},
            bgSelected = ${builtins.toJSON colors.base02},
            stroke = ${builtins.toJSON colors.base03},
            fg = ${builtins.toJSON colors.base05},
            fgDim = ${builtins.toJSON colors.base04},
            fgMuted = ${builtins.toJSON colors.base03},
            accent = ${builtins.toJSON colors.base08},
            green = ${builtins.toJSON colors.base0B},
            yellow = ${builtins.toJSON colors.base0A},
            blue = ${builtins.toJSON colors.base0D},
            magenta = ${builtins.toJSON colors.base0E},
            cyan = ${builtins.toJSON colors.base0C},
          },
        }
      '';
    in
    {
      home.packages = [ pkgs.hammerspoon ];
      home.file =
        lib.listToAttrs (
          map (name: {
            name = ".hammerspoon/${name}";
            value.source = ./files + "/${name}";
          }) luaFiles
        )
        // {
          ".hammerspoon/nix_runtime.lua".text = runtime;
          ".hammerspoon/.nix-config-hash" = {
            text = builtins.hashString "sha256" "${configHash}\n${runtime}";
            onChange = ''
              if /usr/bin/pgrep -x Hammerspoon > /dev/null; then
                ${pkgs.hammerspoon}/Applications/Hammerspoon.app/Contents/Frameworks/hs/hs -q -c 'hs.reload()'
              fi
            '';
          };
        };
    };
}
