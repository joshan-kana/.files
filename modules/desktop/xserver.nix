_: {
  services.xserver = {
    enable = true;
    displayManager.lightdm.enable = false;
    xkb = {
      layout = "us";
      variant = "";
    };
  };
}
