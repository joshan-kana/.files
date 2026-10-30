_:

{
  nixpkgs.overlays = [
    (final: _prev: {
      gh-dash =
        (builtins.getFlake "github:NixOS/nixpkgs/279b4a8275f032c566576b3f181fa0f27197f588")
        .legacyPackages.${final.stdenv.hostPlatform.system}.gh-dash.overrideAttrs
          (
            finalAttrs: old: {
              version = "4.25.2";
              __intentionallyOverridingVersion = true;
              src = final.fetchFromGitHub {
                owner = "dlvhdr";
                repo = "gh-dash";
                rev = "v${finalAttrs.version}";
                hash = "sha256-3iUBuMvA2Xh7UjTiFNEs3tuZMCnSt/bIhTSEDD92yCU=";
              };
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
