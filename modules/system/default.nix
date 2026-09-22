_: {
  identity = import ./identity.nix;
  locale = import ./locale.nix;
  documentation = import ./documentation.nix;
  compatibility = import ./compatibility.nix;
  autoDeploy = import ./auto-deploy.nix;
}
