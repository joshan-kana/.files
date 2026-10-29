_: {
  nixpkgs.overlays = [
    (
      final: prev:
      prev.lib.optionalAttrs
        (builtins.elem prev.stdenv.hostPlatform.system [
          "aarch64-linux"
          "x86_64-linux"
        ])
        {
          agentgateway = final.callPackage ./package.nix { };
        }
    )
  ];
}
