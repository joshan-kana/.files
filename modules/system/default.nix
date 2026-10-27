_: {
  identity = import ./identity.nix;
  privilege = import ./privilege.nix;
  privilegeSshAgent = import ./privilege-ssh-agent.nix;
  homeManager = import ./home-manager.nix;
  locale = import ./locale.nix;
  documentation = import ./documentation.nix;
  maintenance = import ./maintenance.nix;
  compatibility = import ./compatibility.nix;
  autoDeploy = import ./auto-deploy.nix;
}
