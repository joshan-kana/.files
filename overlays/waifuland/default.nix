_: {
  nixpkgs.overlays = [
    (
      _final: prev:
      prev.lib.optionalAttrs prev.stdenv.hostPlatform.isLinux {
        waifuland = prev.stdenv.mkDerivation (finalAttrs: {
          pname = "waifuland";
          version = "0.0.0-unstable-2026-11-11";

          src = prev.fetchFromGitHub {
            owner = "shinkuan";
            repo = "Waifuland";
            rev = "f63acf425ee0b739ae0a3a0d939d5a699e775adf";
            hash = "sha256-XgpDB9fH2hgulJwncWyrxLXbTPV1VsAlEvwSnOlZF1k=";
          };

          cubismSdkArchive = prev.fetchurl {
            url = "https://cubism.live2d.com/sdk-native/bin/CubismSdkForNative-5-r.5.zip";
            hash = "sha256-f/Oku8GcCocollqlIqt36xGyUpFkU+aKinjTtxGIuxI=";
          };

          nativeBuildInputs = [
            prev.cmake
            prev.makeWrapper
            prev.pkg-config
            prev.unzip
            prev.wayland
            prev.wayland-scanner.bin
          ];

          buildInputs = [
            prev.wayland
            prev.libGL
            prev.libGLU
            prev.libglvnd
            prev.libxkbcommon
          ];

          postPatch = ''
            unzip -q ${finalAttrs.cubismSdkArchive}
            mkdir -p thirdParty/glew
            tar xf ${prev.glew.src} -C thirdParty/glew --strip-components=1
            substituteInPlace CMakeLists.txt \
              --replace-fail 'pkg_get_variable(WAYLAND_SCANNER wayland-scanner wayland_scanner)' 'set(WAYLAND_SCANNER "${prev.wayland-scanner.bin}/bin/wayland-scanner")'
            substituteInPlace CMakeLists.txt \
              --replace-fail '/lib/linux/x86_64/libLive2DCubismCore.a' '/lib/${
                if prev.stdenv.hostPlatform.isAarch64 then "experimental/linux/arm64" else "linux/x86_64"
              }/libLive2DCubismCore.a'
          '';

          enableParallelBuilding = true;

          installPhase = ''
            runHook preInstall
            install -Dm755 bin/waifuland "$out/bin/waifuland"
            install -Dm755 ../waifuland-ctl "$out/bin/waifuland-ctl"
            install -d "$out/share/applications"
            cat > "$out/share/applications/waifuland.desktop" <<'DESKTOP'
            [Desktop Entry]
            Name=Waifuland
            Comment=Live2D desktop companion
            Exec=waifuland
            Icon=face-smile
            Type=Application
            Terminal=false
            Categories=Utility;
            DESKTOP
            runHook postInstall
          '';

          postFixup = ''
            wrapProgram "$out/bin/waifuland-ctl" --prefix PATH : ${prev.lib.makeBinPath [ prev.socat ]}
          '';

          passthru.autoUpdate = false;

          meta = {
            description = "Native Wayland Live2D character viewer";
            homepage = "https://github.com/shinkuan/Waifuland";
            license = prev.lib.licenses.unfree;
            platforms = prev.lib.platforms.linux;
            mainProgram = "waifuland";
          };
        });
      }
    )
  ];
}
