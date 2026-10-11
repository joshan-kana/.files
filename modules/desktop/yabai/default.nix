{ lib, system, ... }:

let
  inherit (lib.systems.elaborate system) isDarwin;
in
{
  home = _: {
    xdg.configFile."yabai/yabairc".source = ./files/yabairc;
  };
}
// lib.optionalAttrs isDarwin {
  services.yabai = {
    enable = true;
    enableScriptingAddition = true;
  };
}
