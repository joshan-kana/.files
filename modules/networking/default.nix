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
  mdns =
    { lib, pkgs, ... }:
    {
      services.avahi = {
        enable = true;
        openFirewall = true;
      };

      # Keep `.local` NSS resolution without the full mDNS fallback, which
      # probes arbitrary reverse lookups and can block them for five seconds.
      system.nssModules = [ pkgs.nssmdns ];
      system.nssDatabases.hosts = lib.mkBefore [ "mdns4_minimal [NOTFOUND=return]" ];
    };

  /**
    Tailscale client daemon for ordinary hosts.
  */
  tailscaleClient = _: {
    services.tailscale = {
      enable = true;
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
