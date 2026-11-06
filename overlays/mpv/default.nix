_: {
  nixpkgs.overlays = [
    (final: prev: {
      libplacebo-mpv = prev.libplacebo.overrideAttrs (old: {
        passthru = (old.passthru or { }) // {
          updateMode = "branch";
          autoUpdate = false;
        };
        version = "7.387.0";
        src = prev.fetchFromGitHub {
          owner = "haasn";
          repo = "libplacebo";
          rev = "v7.387.0";
          hash = "sha256-PYi21y7uAZUsbn9nqn4ZP8QB9iQ9pRvnIKdOtG0WeIw=";
        };
      });
      mpv-unwrapped =
        (prev.mpv-unwrapped.override { libplacebo = final.libplacebo-mpv; }).overrideAttrs
          (old: {
            passthru = (old.passthru or { }) // {
              autoUpdate = false;
            };
          });
      mpv = (prev.mpv.override { inherit (final) mpv-unwrapped; }).overrideAttrs (old: {
        passthru = (old.passthru or { }) // {
          autoUpdate = false;
        };
      });
    })
  ];
}
