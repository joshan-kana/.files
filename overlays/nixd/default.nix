_: {
  nixpkgs.overlays = [
    (_final: prev: {
      nixd = prev.nixd.overrideAttrs (old: {
        # nixf's Op.h includes Tokens.h without its installed subdirectory.
        env.NIX_CFLAGS_COMPILE =
          (old.env.NIX_CFLAGS_COMPILE or "") + " -I${prev.lib.getDev prev.nixf}/include/nixf/Parse";
        patches = (old.patches or [ ]) ++ [
          ../../patches/nixd/join-evaluation-workers-before-callback-teardown.patch
          ../../patches/nixd/complete-options-in-merged-attrsets.patch
        ];
        passthru = (old.passthru or { }) // {
          autoUpdate = false;
        };
      });
    })
  ];
}
