_:
let
  version = "1.2.4";
  hashes = {
    aarch64-linux = "sha256-2VBRfJhp9PxsGT62n+LnLeRGXO09zWEc5alsvf7lwsc=";
    x86_64-linux = "sha256-qJhCkU6HR4e86M/B6PTTF+ri1IBGJPjwf/YMUBXAV8M=";
  };
in
{
  nixpkgs.overlays = [
    (
      _final: prev:
      prev.lib.optionalAttrs (builtins.hasAttr prev.stdenv.hostPlatform.system hashes) {
        nowcaption = prev.appimageTools.wrapType2 {
          pname = "nowcaption";
          inherit version;
          src = prev.fetchurl {
            url = "https://github.com/Techlm77/NowCaption/releases/download/v${version}/NowCaption-${version}-${
              if prev.stdenv.hostPlatform.isAarch64 then "aarch64" else "x86_64"
            }.AppImage";
            hash = hashes.${prev.stdenv.hostPlatform.system};
          };
          extraInstallCommands = ''
            mkdir -p "$out/share/applications"
            cat > "$out/share/applications/nowcaption.desktop" <<'DESKTOP'
            [Desktop Entry]
            Type=Application
            Name=NowCaption
            Comment=Offline live captions for desktop audio and microphone
            Exec=nowcaption
            Icon=accessibility
            Categories=AudioVideo;Accessibility;
            Terminal=false
            DESKTOP
          '';
          passthru.autoUpdate = true;
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
