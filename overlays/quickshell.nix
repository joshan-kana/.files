_:

{
  nixpkgs.overlays = [
    (_final: prev: {
      quickshell = prev.quickshell.overrideAttrs (old: {
        version = "0.3.1-patched";
        __intentionallyOverridingVersion = true;

        src = prev.fetchFromGitea {
          domain = "git.outfoxxed.me";
          owner = "quickshell";
          repo = "quickshell";
          tag = "v0.3.1";
          hash = "sha256-CLX2Zp5i5BuLbOxNOkwRd9YY84IOrACNxBV79o9/F9Y=";
        };

        patches = (old.patches or [ ]) ++ [
          ../patches/quickshell/networkmanager-restart.patch
          ../patches/quickshell/wifi-security-live-ap.patch
        ];
      });
    })
  ];
}
