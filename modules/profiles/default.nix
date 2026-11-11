_:

{
  desktop.boot = {
    plymouth.enable = true;
    kernelParams = [
      "quiet"
      "systemd.show_status=1"
    ];
  };
}
