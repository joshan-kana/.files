{ config, ... }:

{
  # Prevent ARP flux between the physical Ethernet interface and the
  # AdGuard macvlan shim. Each interface must answer ARP only for the
  # IPv4 addresses actually assigned to that interface.
  boot.kernel.sysctl = {
    "net.ipv4.conf.all.arp_ignore" = 1;
    "net.ipv4.conf.default.arp_ignore" = 1;
    "net.ipv4.conf.all.arp_announce" = 2;
    "net.ipv4.conf.default.arp_announce" = 2;
  };

  networking.networkmanager.enable = true;
  networking.networkmanager.unmanaged = [
    "interface-name:adguard-shim"
  ];
  networking.networkmanager.ensureProfiles.profiles."wired-static" = {
    connection = {
      id = "wired-static";
      type = "ethernet";
      "interface-name" = "end0";
      autoconnect = true;
      "autoconnect-priority" = 100;
    };
    ipv4 = {
      method = "manual";
      address1 = "192.168.1.3/24,192.168.1.1";
      dns = "192.168.1.2;192.168.1.1;1.1.1.1;";
      "ignore-auto-dns" = true;
    };
    ipv6 = {
      method = "auto";
      "ignore-auto-dns" = true;
    };
  };

  services.avahi = {
    enable = true;
    nssmdns4 = true;
    openFirewall = true;
  };

  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
    };
  };

  services.tailscale = {
    useRoutingFeatures = "server";
    extraUpFlags = [ "--advertise-routes=192.168.1.0/24" ];
    extraSetFlags = [ "--hostname=${config.networking.hostName}" ];
  };
}
