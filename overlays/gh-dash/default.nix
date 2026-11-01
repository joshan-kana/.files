_:

{
  nixpkgs.overlays = [
    (final: prev: {
      gh-dash = prev.gh-dash.overrideAttrs (
        finalAttrs: old: {
          version = "4.26.2";
          src = final.fetchFromGitHub {
            owner = "dlvhdr";
            repo = "gh-dash";
            rev = "v${finalAttrs.version}";
            hash = "sha256-ohhNiuEwt22vzwPBLz+1yWEFakaP6oKJGB070KdQu40=";
          };
          vendorHash = "sha256-edFzZpM1DIwFnMLQlOuh5c8CFzYm3X2YheGFDgOLZ0I=";
          passthru = (old.passthru or { }) // {
            autoUpdate = false;
          };

          patches = (old.patches or [ ]) ++ [
            ../../patches/gh-dash/projects-v2.patch
            ../../patches/gh-dash/issue-relationships.patch
          ];

          meta = old.meta // {
            description = "GitHub dashboard with native Projects and issue relationships";
          };
        }
      );
    })
  ];
}
