{ inputs, ... }: {
  nixpkgs.overlays = [
    (
      final: prev:
      prev.lib.optionalAttrs
        (builtins.hasAttr prev.stdenv.hostPlatform.system inputs.nix-openclaw.packages)
        {
          openclaw-gateway =
            inputs.nix-openclaw.packages.${final.stdenv.hostPlatform.system}.openclaw-gateway;
        }
    )
  ];
}
