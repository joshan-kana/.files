_: {
  nixpkgs.overlays = [
    (
      _final: prev:
      let
        inherit (prev) lib;
        system = prev.stdenv.hostPlatform.system;
        release = {
          version = "26.1029.61003";
          hash = "sha256-Q975gJnpSDfwe5dr6YE4JRhZrliDHQV9VIPosgkGqaQ=";
        };
        linuxHashes = {
          x86_64 = "sha256-BayLVMODb2+Z5PGtuLZsHwqg7W191es25JdqAdM2uYY=";
          aarch64 = "sha256-XYwXNRPkqXFziWH9Ekp/ps+QmQhdAR5E3FUnl4zf/go=";
        };
        inherit (release) version;
        isDarwin = prev.stdenv.hostPlatform.isDarwin;
        isLinux = builtins.elem system [
          "aarch64-linux"
          "x86_64-linux"
        ];
        linuxArch = if system == "aarch64-linux" then "aarch64" else "x86_64";
      in
      lib.optionalAttrs isDarwin {
        chatgpt = import ../../lib/mac-app.nix { inherit prev; } {
          inherit release;
          pname = "chatgpt";
          appName = "ChatGPT.app";
          homepage = "https://chatgpt.com/";
          license = lib.licenses.unfree;
          passthru = {
            autoUpdate = false;
            updateGroup = "chatgpt";
            updateFilename = "overlays/chatgpt/default.nix";
          };
          url = r: "https://persistent.oaistatic.com/codex-app-prod/ChatGPT-darwin-arm64-${r.version}.zip";
          unpacker = prev.unzip;
        };
      }
      // lib.optionalAttrs isLinux {
        chatgpt = prev.stdenv.mkDerivation {
          pname = "chatgpt";
          inherit version;
          src = prev.fetchurl {
            url = "https://persistent.oaistatic.com/codex-app-prod/linux/arch/${version}/${linuxArch}/chatgpt-bin-${version}-1-${linuxArch}.pkg.tar.zst";
            hash = linuxHashes.${linuxArch};
          };
          sourceRoot = ".";
          nativeBuildInputs = with prev; [
            autoPatchelfHook
            zstd
          ];
          dontWrapQtApps = true;
          buildInputs = with prev; [
            alsa-lib
            at-spi2-atk
            atk
            cairo
            cups
            dbus
            expat
            gdk-pixbuf
            glib
            gtk3
            libdrm
            libGL
            libnotify
            libsecret
            libusb1
            libxkbcommon
            libx11
            libxcb
            libxcomposite
            libxdamage
            libxext
            libxfixes
            libxrandr
            mesa
            nspr
            nss
            openssl
            pango
            qt6.qtbase
            systemd
            tpm2-tss
            stdenv.cc.cc.lib
          ];
          # Unused Qt 5, musl, and Android compatibility binaries are bundled upstream.
          autoPatchelfIgnoreMissingDeps = [
            "libQt5Core.so.5"
            "libQt5Gui.so.5"
            "libQt5Widgets.so.5"
            "libc.musl-x86_64.so.1"
            "libc.musl-aarch64.so.1"
            "liblog.so"
            "libc++_shared.so"
          ];
          unpackPhase = ''
            runHook preUnpack
            tar --use-compress-program=unzstd -xf "$src"
            runHook postUnpack
          '';
          installPhase = ''
            runHook preInstall
            mkdir -p "$out/lib" "$out/bin" "$out/share/applications" "$out/share/pixmaps"
            cp -a usr/lib/chatgpt "$out/lib/"
            ln -s ../lib/chatgpt/codex-launcher "$out/bin/chatgpt"
            cp usr/share/applications/chatgpt.desktop "$out/share/applications/"
            cp usr/share/pixmaps/chatgpt.png "$out/share/pixmaps/"
            runHook postInstall
          '';
          passthru = {
            updateGroup = "chatgpt";
          };
          meta = {
            homepage = "https://chatgpt.com/";
            license = lib.licenses.unfree;
            platforms = [
              "aarch64-linux"
              "x86_64-linux"
            ];
            sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
            mainProgram = "chatgpt";
          };
        };
      }
    )
  ];
}
