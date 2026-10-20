_: {
  nixpkgs.overlays = [
    (
      final: prev:
      prev.lib.optionalAttrs prev.stdenv.hostPlatform.isLinux {
        linux-desktop-spectrum = final.stdenv.mkDerivation {
          pname = "linux-desktop-spectrum";
          version = "0.1.0";
          src = ../../modules/desktop/hyprland/shell/spectrum;

          nativeBuildInputs = [ final.pkg-config ];
          buildInputs = [ final.pipewire ];

          buildPhase = ''
            runHook preBuild
            $CXX -std=c++20 -O3 -DNDEBUG -Wall -Wextra main.cpp -o linux-desktop-spectrum $(pkg-config --cflags --libs libpipewire-0.3) -pthread
            runHook postBuild
          '';

          installPhase = ''
            runHook preInstall
            install -Dm755 linux-desktop-spectrum "$out/bin/linux-desktop-spectrum"
            runHook postInstall
          '';
          meta.mainProgram = "linux-desktop-spectrum";
        };
      }
    )
  ];
}
