_:
let
  version = "models-v4";
  hashes = {
    aarch64-linux = "sha256-2VBRfJhp9PxsGT62n+LnLeRGXO09zWEc5alsvf7lwsc=";
    x86_64-linux = "sha256-qJhCkU6HR4e86M/B6PTTF+ri1IBGJPjwf/YMUBXAV8M=";
  };
in
{
  nixpkgs.overlays = [
    (
      _final: prev:
      let
        system = prev.stdenv.hostPlatform.system;
      in
      prev.lib.optionalAttrs (builtins.hasAttr system hashes) {
        nowcaption =
          let
            src = prev.fetchurl {
              url = "https://github.com/Techlm77/NowCaption/releases/download/v${version}/NowCaption-${version}-${
                if system == "aarch64-linux" then "aarch64" else "x86_64"
              }.AppImage";
              hash = hashes.${system};
            };
            contents = prev.appimageTools.extract {
              pname = "nowcaption";
              inherit version src;
            };
          in
          prev.appimageTools.wrapType2 {
            pname = "nowcaption";
            inherit version src;
            extraInstallCommands = ''
              install -Dm644 ${contents}/usr/share/applications/io.github.Techlm77.NowCaption.desktop \
                "$out/share/applications/io.github.Techlm77.NowCaption.desktop"
              install -Dm644 ${contents}/io.github.Techlm77.NowCaption.svg \
                "$out/share/icons/hicolor/scalable/apps/io.github.Techlm77.NowCaption.svg"
            '';
            passthru = {
              autoUpdate = true;
              updateGroup = "nowcaption";
              updateUrl = "https://github.com/Techlm77/NowCaption";
              updateGithubReleases = true;
              updateRegex = "^v([0-9]+\\.[0-9]+\\.[0-9]+)$";
              updateFilename = "overlays/nowcaption/default.nix";
            };
            meta = {
              description = "Offline live captions for desktop audio and microphone";
              homepage = "https://github.com/Techlm77/NowCaption";
              license = prev.lib.licenses.mit;
              platforms = builtins.attrNames hashes;
              mainProgram = "nowcaption";
              sourceProvenance = [ prev.lib.sourceTypes.binaryNativeCode ];
            };
          };
      }
    )
  ];
}
