_: {
  nixpkgs.overlays = [
    (
      _final: prev:
      let
        release = {
          version = "16.3.0";
          hash = "sha256-GcznvtPUinIiQspoO9G65Aa2qH/tUgco0ckd7hdbdeQ=";
        };
      in
      prev.lib.optionalAttrs prev.stdenv.hostPlatform.isDarwin {
        karabiner-elements = prev.stdenvNoCC.mkDerivation {
          pname = "karabiner-elements";
          inherit (release) version;
          src = prev.fetchurl {
            url = "https://github.com/pqrs-org/Karabiner-Elements/releases/download/v${release.version}/Karabiner-Elements-${release.version}.dmg";
            inherit (release) hash;
          };
          nativeBuildInputs = [ prev.undmg ];
          sourceRoot = ".";
          dontBuild = true;
          dontFixup = true;
          installPhase = ''
            runHook preInstall
            install -Dm444 Karabiner-Elements.pkg \
              "$out/share/karabiner-elements/Karabiner-Elements.pkg"
            mkdir -p "$out/bin"
            cat > "$out/bin/karabiner_cli" <<'SH'
            #!/bin/sh
            exec "/Library/Application Support/org.pqrs/Karabiner-Elements/bin/karabiner_cli" "$@"
            SH
            chmod +x "$out/bin/karabiner_cli"
            runHook postInstall
          '';
          passthru = {
            autoUpdate = true;
            updateScript = [
              "${prev.python3}/bin/python3"
              "${../../scripts/update-cask.py}"
              "karabiner-elements"
            ];
          };
          meta = {
            description = "Powerful keyboard customizer for macOS";
            homepage = "https://karabiner-elements.pqrs.org/";
            license = prev.lib.licenses.unlicense;
            platforms = prev.lib.platforms.darwin;
            sourceProvenance = [ prev.lib.sourceTypes.binaryNativeCode ];
          };
        };
      }
    )
  ];
}
