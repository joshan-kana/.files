{ lib, system, ... }: {
  home = _: {
    xdg.configFile."yabai/yabairc".source = ./files/yabairc;
  };
  config = lib.optionalAttrs (lib.systems.elaborate system).isDarwin {
    services.yabai = {
      enable = true;
      enableScriptingAddition = true;
    };
  };
}
