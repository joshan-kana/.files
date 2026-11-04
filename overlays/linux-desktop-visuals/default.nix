_: {
  nixpkgs.overlays = [
    (
      final: prev:
      prev.lib.optionalAttrs prev.stdenv.hostPlatform.isLinux {
        linux-desktop-visuals = final.stdenv.mkDerivation {
          pname = "linux-desktop-visuals";
          version = "0.1.0";
          src = ../../modules/desktop/hyprland/shell/visuals;

          dontWrapQtApps = true;
          nativeBuildInputs = [ final.pkg-config ];
          buildInputs = [
            final.qt6.qtbase
            final.qt6.qtdeclarative
          ];

          buildPhase = ''
            runHook preBuild
            ${final.qt6.qtbase}/libexec/moc -I${final.qt6.qtdeclarative}/include --output-json plugin.cpp -o plugin.moc
            ${final.qt6.qtdeclarative}/libexec/qmltyperegistrar --import-name LinuxDesktop.Visuals --major-version 1 --minor-version 0 --generate-qmltypes plugins.qmltypes -o qmltyperegistrations.cpp plugin.moc.json
            $CXX -std=c++20 -O3 -fPIC -shared -Wall -Wextra plugin.cpp -o liblinux-desktop-visuals.so $(pkg-config --cflags --libs Qt6Core Qt6Gui Qt6Qml Qt6Quick)
            runHook postBuild
          '';

          installPhase = ''
            runHook preInstall
            install -Dm755 liblinux-desktop-visuals.so "$out/lib/qt-6/qml/LinuxDesktop/Visuals/liblinux-desktop-visuals.so"
            install -Dm644 qmldir "$out/lib/qt-6/qml/LinuxDesktop/Visuals/qmldir"
            install -Dm644 plugins.qmltypes "$out/lib/qt-6/qml/LinuxDesktop/Visuals/plugins.qmltypes"
            runHook postInstall
          '';
        };
      }
    )
  ];
}
