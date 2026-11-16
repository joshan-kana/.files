# Backport ncmpcpp/ncmpcpp@10718bbfb69ad54d54324d3e4e86514815d4245c
# until the packaged source includes the libc++ 22 compatibility fix.
_final: prev: {
  ncmpcpp = prev.ncmpcpp.overrideAttrs (old: {
    patches = (old.patches or [ ]) ++ [ ../../patches/ncmpcpp/libcxx22-transform-iterator.patch ];
    passthru = (old.passthru or { }) // {
      autoUpdate = false;
    };
  });
}
