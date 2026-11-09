{
  nixpkgs.overlays = [
    (final: prev: {
      kitty = prev.kitty.overrideAttrs (old: {
        version = "0.49.2";
        src = prev.fetchFromGitHub {
          owner = "kovidgoyal";
          repo = "kitty";
          tag = "v0.49.2";
          hash = "sha256-FstfBzwdh1z7Qy9zWDY7L7mpd5bxnypgqEzqeLe16fY=";
        };
        patches = (old.patches or [ ]) ++ [ ../../patches/kitty/smooth-cursor.patch ];
        passthru = (old.passthru or { }) // {
          autoUpdate = false;
        };
      });
      kitty-virgl = final.kitty.overrideAttrs (old: {
        patches = (old.patches or [ ]) ++ [ ../../patches/kitty/fix-virgl-srgb.patch ];
      });
    })
  ];
}
