# Backport nlewo/comin#239 until the pinned upstream revision supports
# nix-darwin configurations without the legacy activate-user script.
_final: prev: {
  comin = prev.comin.overrideAttrs (old: {
    patches = (old.patches or [ ]) ++ [ ../../patches/comin/darwin-activation.patch ];
    passthru = (old.passthru or { }) // {
      autoUpdate = false;
    };
  });
}
