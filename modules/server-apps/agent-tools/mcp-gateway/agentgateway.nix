{ inputs, pkgs }:

pkgs.callPackage "${inputs.agentgateway-bin}/package.nix" { }
