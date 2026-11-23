_: {
  nixpkgs.overlays = [
    (
      _final: prev:
      let
        version = "1.5.2";
        src = prev.fetchFromGitHub {
          owner = "Alexandru2984";
          repo = "animaEngine";
          rev = "v${version}";
          hash = "sha256-ZUAMsLGRSvQN1F4mAnhZ3hoDSD0Y0fDiA+C/G+d0CsM=";
        };
      in
      prev.lib.optionalAttrs prev.stdenv.hostPlatform.isLinux {
        anima-engine = prev.rustPlatform.buildRustPackage {
          pname = "anima-engine";
          inherit version src;
          cargoLock.lockFile = "${src}/Cargo.lock";
          # Upstream release-profile tests link large GPU test binaries; run separate tests as needed.
          doCheck = false;
          preBuild = "export NIX_BUILD_CORES=4";
          nativeBuildInputs = [
            prev.pkg-config
            prev.makeWrapper
          ];
          buildInputs = [
            prev.alsa-lib
            prev.libxkbcommon
            prev.wayland
          ];
          postInstall = ''
            mv "$out/bin/anima_engine" "$out/bin/anima-engine-unwrapped"
            makeWrapper "$out/bin/anima-engine-unwrapped" "$out/bin/anima-engine" \
              --set-default ANIMA_USE_WAYLAND_NATIVE 1 \
              --prefix LD_LIBRARY_PATH : ${
                prev.lib.makeLibraryPath [
                  prev.libxkbcommon
                  prev.wayland
                  prev.libx11
                  prev.libxcursor
                  prev.libxi
                  prev.libxrandr
                  prev.libGL
                  prev.vulkan-loader
                ]
              }
            install -Dm644 data/eu.animaengine.Anima.desktop "$out/share/applications/eu.animaengine.Anima.desktop"
            install -Dm644 data/anima-engine.svg "$out/share/icons/hicolor/scalable/apps/anima-engine.svg"
          '';
          passthru.autoUpdate = true;
          meta = {
            description = "Animated desktop companions with native Wayland support";
            homepage = "https://github.com/Alexandru2984/animaEngine";
            license = prev.lib.licenses.mit;
            mainProgram = "anima-engine";
            platforms = prev.lib.platforms.linux;
          };
        };
      }
    )
  ];
}
