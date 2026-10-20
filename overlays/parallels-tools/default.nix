_: {
  nixpkgs.overlays = [
    (
      _final: prev:
      prev.lib.optionalAttrs (prev.stdenv.hostPlatform.isLinux && prev.stdenv.hostPlatform.isAarch64) {
        prl-tools = prev.prl-tools.overrideAttrs (
          _finalAttrs: previousAttrs: {
            version = "27.0.0-58628";
            src = previousAttrs.src.overrideAttrs {
              outputHash = "sha256-WH3Ivc+ahWzlAbBpjlh37yUtSCIb27TqvxJmrR1Rq+8=";
            };
          }
        );
      }
    )
  ];
}
