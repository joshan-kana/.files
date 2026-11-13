_:
let
  release = {
    version = "10.0.8";
    hash = "sha256-UB0+KTOjhfGDNJdGn1UyZmLffl1AQBI5gmxA1vpYPxY=";
  };
in
{
  nixpkgs.overlays = [
    (
      _final: prev:
      prev.lib.optionalAttrs prev.stdenv.hostPlatform.isDarwin {
        kicad = prev.stdenvNoCC.mkDerivation {
          pname = "kicad";
          inherit (release) version;
          src = prev.fetchurl {
            url = "https://github.com/KiCad/kicad-source-mirror/releases/download/${release.version}/kicad-unified-universal-${release.version}.dmg";
            inherit (release) hash;
          };
          nativeBuildInputs = [ prev._7zz ];
          sourceRoot = ".";
          dontBuild = true;
          dontFixup = true;
          installPhase = ''
            runHook preInstall
            suite="$(find . -type d -name KiCad -exec test -d '{}/KiCad.app' \; -print -quit)"
            test -n "$suite"
            mkdir -p "$out/Applications" "$out/bin" "$out/share/kicad"
            cp -R "$suite" "$out/Applications/KiCad"
            cp -R "$(dirname "$suite")/demos" "$out/share/kicad/demos"
            for command in kicad-cli idf2vrml idfcyl idfrect dxf2idf; do
              ln -s "$out/Applications/KiCad/KiCad.app/Contents/MacOS/$command" "$out/bin/$command"
            done
            runHook postInstall
          '';
          passthru = {
            autoUpdate = true;
            updateFilename = "overlays/kicad/default.nix";
            updateUrl = "https://github.com/KiCad/kicad-source-mirror";
            updateGithubReleases = true;
          };
          meta = {
            homepage = "https://www.kicad.org";
            description = "Electronics design automation suite";
            license = prev.lib.licenses.gpl3Plus;
            platforms = [ "aarch64-darwin" ];
            sourceProvenance = [ prev.lib.sourceTypes.binaryNativeCode ];
          };
        };
      }
    )
  ];
}
