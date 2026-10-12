_: {
  home = _: {
    xdg.configFile."yabai/yabairc".source = ./files/yabairc;
  };
  services.yabai = {
    enable = true;
    enableScriptingAddition = true;
  };
}
