_:

{
  nixpkgs.overlays = [
    (final: prev: {
      gh-dash = prev.gh-dash.overrideAttrs (
        finalAttrs: old: {
          version = "4.26.3";
          src = final.fetchFromGitHub {
            owner = "dlvhdr";
            repo = "gh-dash";
            rev = "v${finalAttrs.version}";
            hash = "sha256-OxU3gJyRD37nHzk2UyB3eQwulKmftcE8ZPsUZbJXHe0=";
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
