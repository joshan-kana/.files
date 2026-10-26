_: {
  nixpkgs.overlays = [
    (
      _final: prev:
      prev.lib.optionalAttrs prev.stdenv.hostPlatform.isDarwin {
        # Unreleased upstream fix for Dock Space creation on macOS Tahoe 26.6+.
        # https://github.com/asmvik/yabai/commit/dd845723416f5fe92af49fad5ebab00369e07edd
        yabai = prev.yabai.overrideAttrs (old: {
          patches = (old.patches or [ ]) ++ [
            ../../patches/yabai/tahoe-26.6-space-creation.patch
          ];
        });
      }
    )
  ];
}
