{
  editScope,
  lib,
  moduleRegistry,
  modulesPath,
  ...
}:

{
  inherit (moduleRegistry)
    system
    theme
    cli
    secrets
    virtualisation
    ;

  networking = editScope moduleRegistry.networking {
    ssh = { lib, ... }: {
      services.openssh = {
        enable = lib.mkForce true;
        ports = [ 32223 ];
      };
    };
  };

  nix = editScope moduleRegistry.nix {
    builders =
      {
        config,
        inherited,
        lib,
        ...
      }:
      {
        nix.buildMachines = lib.filter (
          builder: builder.hostName != "Joshans-MacBook-Pro.local:32223"
        ) inherited.nix.buildMachines;

        users.users.${config.dotfiles.users.primary.name}.openssh.authorizedKeys.keys = [
          "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEER0NqlNCN0MYwBhWKNnk8iNSApeiDPiXDziS5aU5jz nix-builder"
        ];
      };
  };

  imports = [
    ./generated.nix
    "${modulesPath}/virtualisation/lxc-container.nix"
  ];

  dotfiles = {
    profile.name = "nixos-orbstack";
    paths.repoPath = "/Users/joshan/.files";
    services.ollama.url = "http://host.orb.internal:11434/v1";
    scopes = {
      networking.mdns.enable = false;
      virtualisation = {
        children.enable = false;
        vm.enable = true;
      };
      cli.codex.enable = false;
    };
  };

  container = { config, ... }: {
    # OrbStack LXC containers have no Wi-Fi and /etc may be read-only.
    systemd.services.wpa_supplicant.enable = lib.mkIf (config.boot.isContainer or false) (
      lib.mkForce false
    );
    networking.wireless.enable = lib.mkIf (config.boot.isContainer or false) (lib.mkForce false);

    # Ensure the useful wired profile wins over OrbStack/NetworkManager's
    # auto-generated eth0 profile.
    networking.networkmanager.ensureProfiles = lib.mkIf (config.boot.isContainer or false) {
      profiles."Wired connection 1" = {
        connection = {
          id = "Wired connection 1";
          type = "ethernet";
          interface-name = "eth0";
          autoconnect = true;
          autoconnect-priority = 100;
        };
        ipv4.method = "auto";
        ipv6.method = "auto";
      };

      profiles.eth0 = {
        connection = {
          id = "eth0";
          type = "ethernet";
          interface-name = "eth0";
          autoconnect = false;
        };
        ipv4.method = "disabled";
        ipv6.method = "disabled";
      };
    };
  };

  hostEnvironment = _: {
    environment.sessionVariables.SSH_AUTH_SOCK = "/opt/orbstack-guest/run/host-ssh-agent.sock";

    programs.ssh.extraConfig = ''
      Host *
        ForwardAgent yes
    '';
  };

}
