{ inputs, ... }:

{
  nixpkgs.overlays = [ inputs.nh.overlays.default ];
}
