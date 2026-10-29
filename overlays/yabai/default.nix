_: {
  nixpkgs.overlays = [
    (
      _final: prev:
      prev.lib.optionalAttrs prev.stdenv.hostPlatform.isDarwin {
        # Unreleased upstream fix for Dock Space creation on macOS Tahoe 26.6+.
        # https://github.com/asmvik/yabai/commit/dd845723416f5fe92af49fad5ebab00369e07edd
        yabai =
          let
            version = "7.1.25";
          in
          prev.yabai.overrideAttrs (old: {
            inherit version;
            src = prev.fetchFromGitHub {
              owner = "asmvik";
              repo = "yabai";
              rev = "refs/tags/v${version}";
              hash = "sha256-61knfbahxxlJnVZy47347slsjUGiQUJyZh58G97SDkE=";
            };
            passthru = (old.passthru or { }) // {
              autoUpdate = false;
            };
            patches = (old.patches or [ ]) ++ [
              ../../patches/yabai/tahoe-26.6-space-creation.patch
            ];
          });
      }
    )
  ];
}
