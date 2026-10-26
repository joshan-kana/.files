_:

{
  nixpkgs.overlays = [
    (
      _final: prev:
      prev.lib.optionalAttrs prev.stdenv.hostPlatform.isLinux {
        quickshell = prev.quickshell.overrideAttrs (old: {
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
