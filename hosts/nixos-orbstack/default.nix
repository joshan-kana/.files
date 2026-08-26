{ modulesPath, ... }:

{
  imports = [
    ../../modules/options/common.nix
    "${modulesPath}/virtualisation/lxc-container.nix"
  ];

  system = import ../../modules/system.nix;
  nix = import ../../modules/nix.nix;
  cli = import ../../modules/cli.nix;
  networking = import ../../modules/networking.nix;
  vm = import ../../modules/vm.nix;
  orbstack = import ./orbstack-generated.nix;
  container = import ./container.nix;
  hostEnvironment = import ./host-env.nix;

  dotfiles = {
    profile.name = "nixos-orbstack";
    paths.repoPath = "/Users/joshan/.files";
    services.ollama.url = "http://host.orb.internal:11434/v1";
  };
}
