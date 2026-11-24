let
  upstream = import ./source.nix;
in
_: {
  nixpkgs.overlays = [
    (final: _prev: {
      comin = upstream.packages.${final.stdenv.hostPlatform.system}.comin.overrideAttrs (old: {
        version = "${old.version}-patched";
        __intentionallyOverridingVersion = true;
        ldflags = [ "-X github.com/nlewo/comin/cmd.version=${old.version}-patched" ];

        patches = (old.patches or [ ]) ++ [
          ../../patches/comin/allow-force-push.patch
          ../../patches/comin/execution-lifecycle.patch
          ../../patches/comin/manual-retry.patch
          ../../patches/comin/deployment-restart.patch
          ../../patches/comin/stream-reconnect.patch
          ../../patches/comin/watch-tui.patch
        ];
        passthru = (old.passthru or { }) // {
          autoUpdate = false;
        };
      });
    })
    (import ./temporary.nix)
  ];
}
