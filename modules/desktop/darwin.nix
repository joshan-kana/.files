{
  hammerspoon = import ./hammerspoon;
  yabai = import ./yabai;
  raycast = { pkgs, ... }: {
    environment.systemPackages = [ pkgs.raycast ];
  };
  karabinerElements = { lib, system, ... }: {
    config = lib.optionalAttrs (lib.systems.elaborate system).isDarwin {
      services.karabiner-elements.enable = true;
    };
  };
}
