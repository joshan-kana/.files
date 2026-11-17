{
  nixpkgs.overlays = [
    (final: prev: {
      kitty = prev.kitty.overrideAttrs (
        finalAttrs: old: {
          version = "0.50.0";
          src = prev.fetchFromGitHub {
            owner = "kovidgoyal";
            repo = "kitty";
            tag = "v0.50.0";
            hash = "sha256-CSSjL931OLZ9wwz9E3rAfMcm+TpczVJzJh9MPfuKmVU=";
          };
          inherit
            (
              (prev.buildGo126Module {
                pname = "kitty-go-modules";
                inherit (finalAttrs) src version;
                vendorHash = "sha256-Oo5ehjdq4HcTxZcKi/rwz8dDZYGxdSS8cqIkbdLBrb8=";
              })
            )
            goModules
            ;
          patches = (old.patches or [ ]) ++ [ ../../patches/kitty/smooth-cursor.patch ];
          passthru = (old.passthru or { }) // {
            autoUpdate = false;
          };
        }
      );
      kitty-virgl = final.kitty.overrideAttrs (old: {
        patches = (old.patches or [ ]) ++ [ ../../patches/kitty/fix-virgl-srgb.patch ];
      });
    })
  ];
}
