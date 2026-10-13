_: {
  identity = import ./identity.nix;
  homeManager = import ./home-manager.nix;
  locale = import ./locale.nix;
  documentation = import ./documentation.nix;
  compatibility = import ./compatibility.nix;
  autoDeploy = import ./auto-deploy.nix;
}
