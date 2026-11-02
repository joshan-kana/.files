_: {
  nixpkgs.overlays = [
    (
      _final: prev:
      let
        version = "2.6.1";
        homepage = "https://www.squirreldisk.com";
        license = prev.lib.licenses.agpl3Only;
      in
      prev.lib.optionalAttrs prev.stdenv.hostPlatform.isDarwin {
        squirreldisk-mac = import ../../lib/mac-app.nix { inherit prev; } {
          token = "squirreldisk";
          release = {
            inherit version;
            hash = "sha256-E84YnLYNGzx8KYPFqWGNbJoOoJeIyKTQUCkO9Z+Jfgo=";
          };
          pname = "squirreldisk-mac";
          appName = "SquirrelDisk.app";
          inherit homepage license;
          updateScript = null;
          updateGroup = "squirreldisk";
          updateUrl = "https://github.com/adileo/squirreldisk";
          url =
            _: "https://github.com/adileo/squirreldisk/releases/download/v${version}/SquirrelDisk-macOS.dmg";
        };
      }
      //
        prev.lib.optionalAttrs
          (
            prev.stdenv.hostPlatform.system == "x86_64-linux"
            || prev.stdenv.hostPlatform.system == "aarch64-linux"
          )
          {
            squirreldisk =
              if prev.stdenv.hostPlatform.isAarch64 then
                prev.rustPlatform.buildRustPackage {
                  pname = "squirreldisk";
                  inherit version;
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
                  passthru = {
                    autoUpdate = true;
                    updateGroup = "squirreldisk";
                  };
                  meta = {
                    inherit homepage license;
                    platforms = [ "aarch64-linux" ];
                    mainProgram = "squirreldisk";
                  };
                }
              else
                prev.appimageTools.wrapType2 rec {
                  pname = "squirreldisk";
                  inherit version;
                  src = prev.fetchurl {
                    url = "https://github.com/adileo/squirreldisk/releases/download/v${version}/SquirrelDisk-x86_64.AppImage";
                    hash = "sha256-rSROPmdpwKuah/1NydQrIAqepU6i+3m9NwKcn6ugJmg=";
                  };
                  passthru = {
                    autoUpdate = true;
                    updateGroup = "squirreldisk";
                  };
                  appimageContents = prev.appimageTools.extract { inherit pname version src; };
                  extraInstallCommands = ''
                    install -Dm444 "${appimageContents}/squirreldisk.desktop" "$out/share/applications/squirreldisk.desktop"
                    mkdir -p "$out/share/icons"
                    cp -R "${appimageContents}/usr/share/icons/hicolor" "$out/share/icons/"
                  '';
                  meta = {
                    inherit homepage license;
                    platforms = [ "x86_64-linux" ];
                    sourceProvenance = [ prev.lib.sourceTypes.binaryNativeCode ];
                    mainProgram = "squirreldisk";
                  };
                };
          }
    )
  ];
}
