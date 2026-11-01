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
              rev = "dd845723416f5fe92af49fad5ebab00369e07edd";
              hash = "sha256-RPiGAuJS+tGsexekIzwgKYf/v+kA3lVn0+qMVIMC2Vk=";
            };
            passthru = (old.passthru or { }) // {
              autoUpdate = false;
            };
          });
      }
    )
  ];
}
