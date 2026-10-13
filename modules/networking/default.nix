{
  lib,
  system,
  ...
}:

let
  inherit (lib.systems.elaborate system) isDarwin isLinux;
  sshSettings = {
    PasswordAuthentication = false;
    KbdInteractiveAuthentication = false;
  };
in
{
  /**
    Tailscale client daemon for ordinary hosts.
  */
  tailscaleClient =
    _:
    (
      lib.optionalAttrs isLinux {
        services.tailscale = {
          enable = true;
          openFirewall = true;
        };
      }
      // lib.optionalAttrs isDarwin {
        # The vendor app owns its macOS network extension and VPN entitlement.
        homebrew.casks = [ "tailscale-app" ];
      }
    );

  /**
    Key-only OpenSSH server access with the firewall opening owned by the service.
  */
  ssh = _: {
    services.openssh = {
      enable = true;
    }
    // lib.optionalAttrs isLinux {
      openFirewall = true;
      settings = sshSettings;
    }
    // lib.optionalAttrs isDarwin {
      extraConfig = lib.concatStringsSep "\n" (
        lib.mapAttrsToList (name: enabled: "${name} ${if enabled then "yes" else "no"}") sshSettings
      );
    };
  };
}
// lib.optionalAttrs isLinux {
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
}
