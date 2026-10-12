{
  hammerspoon = import ./hammerspoon;
  yabai = import ./yabai;
  raycast = { pkgs, ... }: {
    environment.systemPackages = [ pkgs.raycast ];
  };
  karabinerElements = _: {
    services.karabiner-elements.enable = true;
  };
}
