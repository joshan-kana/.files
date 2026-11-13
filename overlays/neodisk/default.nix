_: {
  nixpkgs.overlays = [
    (
      _final: prev:
      let
        version = "2.91.0";
        homepage = "https://neodisk.app";
        license = prev.lib.licenses.gpl3Only;
      in
      prev.lib.optionalAttrs prev.stdenv.hostPlatform.isDarwin {
        neodisk = import ../../lib/mac-app.nix { inherit prev; } {
          release = {
            inherit version;
            hash = "sha256-Qha/UmyKOH3KtQToHlsZ9a45j523a9eJ9qutc7q86uU=";
          };
          pname = "neodisk";
          appName = "Neodisk.app";
          inherit homepage license;
          unpacker = prev.unzip;
          passthru = {
            autoUpdate = true;
            updateGroup = "neodisk";
            updateFilename = "overlays/neodisk/default.nix";
            updateUrl = "https://github.com/tkslucas/Neodisk";
          };
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
            neodisk = prev.stdenv.mkDerivation {
              pname = "neodisk";
              inherit version;
              src = prev.fetchurl (
                prev.lib.optionalAttrs (prev.stdenv.hostPlatform.system == "aarch64-linux") {
                  url = "https://github.com/tkslucas/Neodisk/releases/download/v${version}/neodisk-${version}-linux-aarch64.tar.gz";
                  hash = "sha256-P72tpfVhJh9yOP4UwWeaAe6kYE4pi33F+QZ2z+2BLys=";
                }
                // prev.lib.optionalAttrs (prev.stdenv.hostPlatform.system == "x86_64-linux") {
                  url = "https://github.com/tkslucas/Neodisk/releases/download/v${version}/neodisk-${version}-linux-x86_64.tar.gz";
                  hash = "sha256-qo9eL61TjvaQ1zKGI8Qolk3Dj5eJ5W/5q6P2QLFBX/A=";
                }
              );
              sourceRoot = ".";
              nativeBuildInputs = with prev; [
                autoPatchelfHook
                wrapGAppsHook4
              ];
              buildInputs = with prev; [
                zstd
                gtk4
                libadwaita
                stdenv.cc.cc.lib
                pango
                glib
                harfbuzz
                cairo
                gdk-pixbuf
                vulkan-loader
                graphene
              ];
              installPhase = ''
                runHook preInstall
                mkdir -p "$out"
                cp -R bin share "$out/"
                substituteInPlace "$out/share/applications/com.lucastakayasu.Neodisk.desktop" \
                  --replace-fail /usr/local/bin/neodisk neodisk
                runHook postInstall
              '';
              passthru = {
                autoUpdate = true;
                updateGroup = "neodisk";
              };
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
