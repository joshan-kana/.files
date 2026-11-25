_: {
  nixpkgs.overlays = [
    (
      _final: prev:
      let
        pname = "squirreldisk";
        version = "2.6.1";
        homepage = "https://www.squirreldisk.com";
        license = prev.lib.licenses.agpl3Only;
        passthru = {
          autoUpdate = true;
          updateGroup = pname;
          updateFilename = "overlays/squirreldisk/default.nix";
          updateUrl = "https://github.com/adileo/squirreldisk";
        };
      in
      prev.lib.optionalAttrs prev.stdenv.hostPlatform.isDarwin {
        squirreldisk = import ../../lib/mac-app.nix { inherit prev; } {
          release = {
            inherit version;
            hash = "sha256-E84YnLYNGzx8KYPFqWGNbJoOoJeIyKTQUCkO9Z+Jfgo=";
          };
          inherit pname;
          appName = "SquirrelDisk.app";
          inherit homepage license;
          inherit passthru;
          url =
            _: "https://github.com/adileo/squirreldisk/releases/download/v${version}/SquirrelDisk-macOS.dmg";
        };
      }
      // prev.lib.optionalAttrs (prev.stdenv.hostPlatform.system == "aarch64-linux") {
        squirreldisk = prev.rustPlatform.buildRustPackage {
          inherit pname version;
          src = prev.fetchFromGitHub {
            owner = "adileo";
            repo = "squirreldisk";
            rev = "v${version}";
            hash = "sha256-SyPxZPZso6gnu0xesD70FtFtDP9hrJk8DdtDzLzg6ys=";
          };
          cargoHash = "sha256-A4xRYpxjl2dF3PGag21hAKOZtJQjI9cLsCLnhSvTGUE=";
          nativeBuildInputs = with prev; [
            pkg-config
            makeWrapper
          ];
          buildInputs = with prev; [
            alsa-lib
            stdenv.cc.cc.lib
            libxkbcommon
            wayland
            libGL
            libx11
            libxcursor
            libxi
            libxrandr
          ];
          postInstall = ''
            install -Dm444 packaging/linux/squirreldisk.desktop "$out/share/applications/squirreldisk.desktop"
            install -Dm444 assets/icon/icon-256.png "$out/share/icons/hicolor/256x256/apps/squirreldisk.png"
            wrapProgram "$out/bin/squirreldisk" --prefix LD_LIBRARY_PATH : ${
              prev.lib.makeLibraryPath [
                prev.libGL
                prev.libxkbcommon
                prev.wayland
              ]
            }
          '';
          inherit passthru;
          meta = {
            inherit homepage license;
            platforms = [ "aarch64-linux" ];
            mainProgram = pname;
          };
        };
      }
      // prev.lib.optionalAttrs (prev.stdenv.hostPlatform.system == "x86_64-linux") {
        squirreldisk = prev.stdenv.mkDerivation {
          inherit pname version;
          src = prev.fetchurl {
            url = "https://github.com/adileo/squirreldisk/releases/download/v${version}/SquirrelDisk-Linux-x86_64.tar.gz";
            hash = "sha256-RcDrnc1m9QXVuqRsmUhyd7zlG2J766oOeHfOqqahvH0=";
          };
          nativeBuildInputs = with prev; [
            autoPatchelfHook
            makeWrapper
          ];
          buildInputs = with prev; [
            alsa-lib
            stdenv.cc.cc.lib
            libxkbcommon
            wayland
            libGL
            vulkan-loader
          ];
          installPhase = ''
            runHook preInstall
            install -Dm755 squirreldisk "$out/bin/squirreldisk"
            install -Dm644 squirreldisk.desktop "$out/share/applications/squirreldisk.desktop"
            install -Dm644 squirreldisk.png "$out/share/icons/hicolor/256x256/apps/squirreldisk.png"
            wrapProgram "$out/bin/squirreldisk" --prefix LD_LIBRARY_PATH : ${
              prev.lib.makeLibraryPath [
                prev.libGL
                prev.libxkbcommon
                prev.wayland
                prev.vulkan-loader
              ]
            }
            runHook postInstall
          '';
          inherit passthru;
          meta = {
            inherit homepage license;
            platforms = [ "x86_64-linux" ];
            sourceProvenance = [ prev.lib.sourceTypes.binaryNativeCode ];
            mainProgram = pname;
          };
        };
      }
    )
  ];
}
