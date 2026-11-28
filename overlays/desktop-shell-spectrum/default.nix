_: {
  nixpkgs.overlays = [
    (
      final: prev:
      prev.lib.optionalAttrs prev.stdenv.hostPlatform.isLinux {
        desktop-shell-spectrum = final.stdenv.mkDerivation {
          pname = "desktop-shell-spectrum";
          version = "0.1.0";
          src = ../../modules/desktop/hyprland/shell/spectrum;

          nativeBuildInputs = [ final.pkg-config ];
          buildInputs = [ final.pipewire ];

          buildPhase = ''
            runHook preBuild
            $CXX -std=c++20 -O3 -DNDEBUG -Wall -Wextra main.cpp -o desktop-shell-spectrum $(pkg-config --cflags --libs libpipewire-0.3) -pthread
            runHook postBuild
          '';

          installPhase = ''
            runHook preInstall
            install -Dm755 desktop-shell-spectrum "$out/bin/desktop-shell-spectrum"
            runHook postInstall
          '';
          meta.mainProgram = "desktop-shell-spectrum";
        };
      }
    )
  ];
}
