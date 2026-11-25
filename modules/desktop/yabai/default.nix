_: {
  home = _: {
    xdg.configFile."yabai/yabairc".source = ./files/yabairc.sh;
  };

  services.yabai = {
    enable = true;
    enableScriptingAddition = true;
  };
}
