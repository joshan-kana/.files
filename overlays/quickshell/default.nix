_:

{
  nixpkgs.overlays = [
    (
      _final: prev:
      prev.lib.optionalAttrs prev.stdenv.hostPlatform.isLinux {
        quickshell =
          let
            version = "0.3.2";
          in
          prev.quickshell.overrideAttrs (old: {
            inherit version;
            src = prev.fetchFromGitea {
              domain = "git.outfoxxed.me";
              owner = "quickshell";
              repo = "quickshell";
              tag = "v${version}";
              hash = "sha256-lPbqsyAD5ZoGFMZ1eqAlTULfeP5Nwhy+XvOowF7BE+E=";
            };
            passthru = (old.passthru or { }) // {
              autoUpdate = false;
            };

            # Bluetooth must recover when BlueZ appears after Quickshell starts.
            patches = (old.patches or [ ]) ++ [
              ../../patches/quickshell/bluez-late-start.patch
            ];

            # Keep qmllint's generated type metadata usable until upstream emits
            # the required QML names, imports, and enum signatures itself.
            postInstall = (old.postInstall or "") + ''
              patch -d "$out/lib/qt-6/qml" -p1 < ${../../patches/quickshell/qmltypes.patch}
            '';
          });
      }
    )
  ];
}
