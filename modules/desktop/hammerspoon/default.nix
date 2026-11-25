{
  lib,
  pkgs,
  browser,
  terminal,
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
    { config, ... }:
    let
      defaultApp =
        executable:
        let
          packages = lib.unique (
            map toString (
              lib.filter (
                package: lib.getName package == executable || (package.meta.mainProgram or null) == executable
              ) config.home.packages
            )
          );
        in
        "{ executable = ${builtins.toJSON executable}, package = ${
          if builtins.length packages == 1 then builtins.toJSON (builtins.head packages) else "nil"
        } }";
      runtime = ''
        return {
          yabai = ${builtins.toJSON (lib.getExe pkgs.yabai)},
          profileBin = ${builtins.toJSON "${config.home.profileDirectory}/bin"},
          browser = ${defaultApp browser},
          terminal = ${defaultApp terminal},
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
            text = builtins.hashString "sha256" "${configHash}\n${runtime}\n${lib.boolToString config.stylix.enable}";
            onChange = ''
              if /usr/bin/pgrep -x Hammerspoon > /dev/null; then
                ${pkgs.hammerspoon}/Applications/Hammerspoon.app/Contents/Frameworks/hs/hs -q -c 'hs.reload()'
              fi
            '';
          };
        };
    };
}
