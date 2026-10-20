_:

{
  nixpkgs.overlays = [
    (
      _final: prev:
      prev.lib.optionalAttrs prev.stdenv.hostPlatform.isLinux {
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
            ../../patches/quickshell/networkmanager-restart.patch
            ../../patches/quickshell/bluez-late-start.patch
            ../../patches/quickshell/wifi-security-live-ap.patch
          ];

          # The pinned release generates incomplete QML type metadata. Repair the
          # declarations used by qmllint without changing Quickshell runtime code.
          postInstall = (old.postInstall or "") + ''
            patch -d "$out/lib/qt-6/qml" -p1 < ${../../patches/quickshell/qmltypes.patch}
          '';
        });
      }
    )
  ];
}
