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
            neodisk = prev.stdenv.mkDerivation {
              pname = "neodisk";
              inherit version;
              src = prev.fetchurl {
                url = "https://github.com/tkslucas/Neodisk/releases/download/v${version}/neodisk-${version}-linux-${
                  if prev.stdenv.hostPlatform.isAarch64 then "aarch64" else "x86_64"
                }.tar.gz";
                hash =
                  if prev.stdenv.hostPlatform.isAarch64 then
                    "sha256-Ad2ClJoNzLeqfN73kHi+ah6Agl8KkUlluMVy30O1drQ="
                  else
                    "sha256-L4LUIZ7MLGoho6aWsdgo2zPFGv1DEJpFoSe/nS/nsHk=";
              };
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
