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
  home = _: {
    home.file =
      lib.listToAttrs (
        map (name: {
          name = ".hammerspoon/${name}";
          value.source = ./files + "/${name}";
        }) luaFiles
      )
      // {
        ".hammerspoon/.nix-config-hash" = {
          text = configHash;
          onChange = ''
            if /usr/bin/pgrep -x Hammerspoon > /dev/null; then
              ${pkgs.hammerspoon}/Applications/Hammerspoon.app/Contents/Frameworks/hs/hs -q -c 'hs.reload()'
            fi
          '';
        };
      };
  };
  environment.systemPackages = [ pkgs.hammerspoon ];
}
