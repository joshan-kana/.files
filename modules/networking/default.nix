_: {
  /**
    NetworkManager-based host networking.
  */
  networkManager = _: {
    networking.networkmanager.enable = true;
  };

  /**
    Multicast DNS discovery through Avahi.
  */
  mdns = _: {
    services.avahi = {
      enable = true;
      nssmdns4 = true;
      openFirewall = true;
    };
  };

  /**
    Key-only OpenSSH server access with the firewall opening owned by the service.
  */
  ssh = _: {
    services.openssh = {
      enable = true;
      openFirewall = true;
      settings = {
        PasswordAuthentication = false;
        KbdInteractiveAuthentication = false;
      };
    };
  };
}
