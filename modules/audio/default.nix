{
  config,
  lib,
  pkgs,
  system,
  ...
}:

let
  inherit (lib.systems.elaborate system) isLinux;
in
lib.optionalAttrs isLinux {
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };
  services.pulseaudio.enable = false;

  home = _: {
    home.packages = with pkgs; [
      config.services.pipewire.package.jack
      (symlinkJoin {
        name = "qjackctl-pipewire";
        paths = [ qjackctl ];
        nativeBuildInputs = [ makeWrapper ];
        postBuild = ''
          rm "$out/bin/qjackctl"
          makeWrapper ${config.services.pipewire.package.jack}/bin/pw-jack "$out/bin/qjackctl" \
            --add-flags ${lib.getExe qjackctl}
        '';
      })
      pavucontrol
    ];
  };

  easyeffects = _: {
    home = _: {
      services.easyeffects = { };
    };
  };
}
