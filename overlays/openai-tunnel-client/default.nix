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
          openai-tunnel-client = final.callPackage ./package.nix { };
        }
    )
  ];
}
