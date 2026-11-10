{
  nixpkgs.overlays = [
    (final: prev: {
      kitty = prev.kitty.overrideAttrs (
        finalAttrs: old: {
          version = "0.49.2";
          src = prev.fetchFromGitHub {
            owner = "kovidgoyal";
            repo = "kitty";
            tag = "v0.49.2";
            hash = "sha256-FstfBzwdh1z7Qy9zWDY7L7mpd5bxnypgqEzqeLe16fY=";
          };
          inherit
            (
              (prev.buildGo126Module {
                pname = "kitty-go-modules";
                inherit (finalAttrs) src version;
                vendorHash = "sha256-iSPPwwu9jllnIxkQeOlJFdDL4xLUGRP2RMW9DPRY6FQ=";
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
