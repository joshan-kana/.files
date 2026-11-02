_: {
  nixpkgs.overlays = [
    (
      _final: prev:
      let
        version = "2.83.2";
        homepage = "https://neodisk.app";
        license = prev.lib.licenses.gpl3Only;
      in
      prev.lib.optionalAttrs prev.stdenv.hostPlatform.isDarwin {
        neodisk = import ../../lib/mac-app.nix { inherit prev; } {
          token = "neodisk";
          release = {
            inherit version;
            hash = "sha256-70EpqemxTJDCI0BFRgc9OIThCuWVWIiOr/QZd0+ljvc=";
          };
          pname = "neodisk";
          appName = "Neodisk.app";
          inherit homepage license;
          unpacker = prev.unzip;
          updateScript = null;
          updateGroup = "neodisk";
          updateUrl = "https://github.com/tkslucas/Neodisk";
          url =
            r: "https://github.com/tkslucas/Neodisk/releases/download/v${r.version}/Neodisk-${r.version}.zip";
        };
      }
      //
        prev.lib.optionalAttrs
          (
            prev.stdenv.hostPlatform.isLinux
            && builtins.elem prev.stdenv.hostPlatform.system [
              "x86_64-linux"
              "aarch64-linux"
            ]
          )
          {
            neodisk = prev.appimageTools.wrapType2 rec {
              pname = "neodisk";
              inherit version;
              src = prev.fetchurl {
                url = "https://github.com/tkslucas/Neodisk/releases/download/v${version}/Neodisk-${version}-${
                  if prev.stdenv.hostPlatform.isAarch64 then "aarch64" else "x86_64"
                }.AppImage";
                hash =
                  if prev.stdenv.hostPlatform.isAarch64 then
                    "sha256-CS9eDeX3Z1vDYso/ECG7y2SMAhz93eR47YR6WoKBLOo="
                  else
                    "sha256-RIEvy3NbTUUMh6Q4f92sr7q/KtIQ40rU2jXjwZrKAzE=";
              };
              passthru = {
                autoUpdate = true;
                updateGroup = "neodisk";
              };
              appimageContents = prev.appimageTools.extract { inherit pname version src; };
              extraInstallCommands = ''
                install -Dm444 "${appimageContents}/com.lucastakayasu.Neodisk.desktop" "$out/share/applications/com.lucastakayasu.Neodisk.desktop"
                mkdir -p "$out/share/icons"
                cp -R "${appimageContents}/usr/share/icons/hicolor" "$out/share/icons/"
              '';
              meta = {
                inherit homepage license;
                platforms = [
                  "x86_64-linux"
                  "aarch64-linux"
                ];
                sourceProvenance = [ prev.lib.sourceTypes.binaryNativeCode ];
                mainProgram = "neodisk";
              };
            };
          }
    )
  ];
}
