{ lib, modulesPath, ... }:

{
  imports = [
    ../../modules/options
    ./generated.nix
    "${modulesPath}/virtualisation/lxc-container.nix"
  ];

  system = import ../../modules/system;
  nix = import ../../modules/nix;
  theme = import ../../modules/theme;
  cli = import ../../modules/cli;
  networking = import ../../modules/networking;
  virtualisation = _: {
    vm = import ../../modules/virtualisation/vm.nix;
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

    home = _: {
      programs.zsh.shellAliases.cpd = ''
        printf "%s" "$(pwd | tr -d "\n")" | pbcopy && echo "Copied path to macOS clipboard"
      '';
    };
  };

  compatibility = { lib, ... }: {
    # Preserve pre-refactor evaluator ownership while shared modules expose
    # both native NixOS and Home Manager configurations. Remove selectively
    # in post-merge behavior changes when enabling the new side is desired.
    programs = {
      lazygit.enable = lib.mkForce false;
      starship.enable = lib.mkForce false;
      neovim.enable = lib.mkForce false;
    };

    home = { lib, ... }: {
      programs = {
        nh.enable = lib.mkForce false;
        direnv.enable = lib.mkForce false;
      };
    };
  };

  dotfiles = {
    profile.name = "nixos-orbstack";
    paths.repoPath = "/Users/joshan/.files";
    services.ollama.url = "http://host.orb.internal:11434/v1";
  };
}
