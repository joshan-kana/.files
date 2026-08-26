{ pkgs, ... }:

{
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    jack.enable = true;
  };
  services.pulseaudio.enable = false;

  environment.systemPackages = with pkgs; [
    qjackctl
    pavucontrol
  ];

  easyeffects = _: {
    home = _: {
      services.easyeffects = { };
    };
  };
}
