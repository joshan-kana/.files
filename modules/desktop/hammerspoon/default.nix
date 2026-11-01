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
    _:
    let
      runtime = ''
        return {
          yabai = ${builtins.toJSON (lib.getExe pkgs.yabai)},
        }
      '';
    in
    {
      home.packages = [ pkgs.hammerspoon ];
      launchd.agents.hammerspoon = {
        enable = true;
        config = {
          Label = "com.joshankana.hammerspoon";
          ProgramArguments = [
            "${pkgs.hammerspoon}/Applications/Hammerspoon.app/Contents/MacOS/Hammerspoon"
          ];
          RunAtLoad = true;
          KeepAlive = true;
        };
      };
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
