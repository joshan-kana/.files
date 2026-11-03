_: {
  nixpkgs.overlays = [
    (
      _final: prev:
      let
        version = "2.9.3";
        src = prev.fetchFromGitHub {
          owner = "nix-community";
          repo = "nixd";
          tag = version;
          hash = "sha256-ud2XcAxUUYenNrGyrh4B9LrDcMZ6eJfPkL60lDcanDI=";
        };
        pinSource = old: {
          inherit version src;
          meta = old.meta // {
            changelog = "https://github.com/nix-community/nixd/releases/tag/${version}";
          };
        };
        nixf = prev.nixf.overrideAttrs pinSource;
        nixt = prev.nixt.overrideAttrs pinSource;
      in
      {
        nixd = (prev.nixd.override { inherit nixf nixt; }).overrideAttrs (old: {
          inherit version src;
          # nixf's Op.h includes Tokens.h without its installed subdirectory.
          env.NIX_CFLAGS_COMPILE =
            (old.env.NIX_CFLAGS_COMPILE or "") + " -I${prev.lib.getDev nixf}/include/nixf/Parse";
          patches = (old.patches or [ ]) ++ [
            ../../patches/nixd/join-evaluation-workers-before-callback-teardown.patch
            ../../patches/nixd/complete-options-in-merged-attrsets.patch
          ];
          passthru = (old.passthru or { }) // {
            autoUpdate = false;
          };
          meta = old.meta // {
            changelog = "https://github.com/nix-community/nixd/releases/tag/${version}";
          };
        });
      }
    )
  ];
}
