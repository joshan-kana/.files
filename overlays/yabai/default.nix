_: {
  nixpkgs.overlays = [
    (
      _final: prev:
      prev.lib.optionalAttrs prev.stdenv.hostPlatform.isDarwin {
        yabai =
          let
            version = "7.1.25";
          in
          prev.yabai.overrideAttrs (old: {
            inherit version;
            src = prev.fetchFromGitHub {
              owner = "asmvik";
              repo = "yabai";
              rev = "b2dc8b4c892d74738a6e865d73048ed2dc3c9ed1";
              hash = "sha256-Nx/zAWis8ZRE/8gkzbE02//zCCGVtMxqhBrV3ikJ+xs=";
            };
            passthru = (old.passthru or { }) // {
              autoUpdate = false;
            };
          });
      }
    )
  ];
}
