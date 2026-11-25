_: {
  nixpkgs.overlays = [
    (
      _final: prev:
      let
        pname = "chatgpt";
        homepage = "https://chatgpt.com/";
        license = lib.licenses.unfree;
        inherit (prev) lib;
        inherit (prev.stdenv) hostPlatform;
        inherit (hostPlatform) system isDarwin isLinux;
        release = {
          version = "26.1120.41243";
          hash = "sha256-74qtMUCeLuOZOp50DPPpTnni1yGeUPSK3qIhfUrPedQ=";
        };
        linuxHashes = {
          x86_64 = "sha256-QwzJzQwRRpN57CpdGDmqJwaE/XHLlMnlmdrWcZcS2TU=";
          aarch64 = "sha256-eO9LHme3Bzc9pqQcTZPbg0k5aOlGP5goQdG9BvdHOrk=";
        };
        inherit (release) version;
        linuxArch = hostPlatform.parsed.cpu.name;
        passthru = rec {
          autoUpdate = true;
          updateGroup = pname;
          updateFilename = "overlays/chatgpt/default.nix";
          updateUrl = "https://persistent.oaistatic.com/codex-app-prod/linux/install-arch.sh";
          updateRegex = ''versions=\(([0-9.]+)'';
          updateScript = [
            "${prev.python3}/bin/python3"
            "${../../scripts/update-version.py}"
            updateFilename
            system
          ];
        };
      in
      lib.optionalAttrs isDarwin {
        chatgpt = import ../../lib/mac-app.nix { inherit prev; } {
          inherit release;
          inherit pname;
          appName = "ChatGPT.app";
          inherit homepage license;
          inherit passthru;
          url = r: "https://persistent.oaistatic.com/codex-app-prod/ChatGPT-darwin-arm64-${r.version}.zip";
          unpacker = prev.unzip;
        };
      }
      // lib.optionalAttrs (isLinux && builtins.hasAttr linuxArch linuxHashes) {
        chatgpt = prev.stdenv.mkDerivation {
          inherit pname version;
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
          inherit passthru;
          meta = {
            inherit homepage license;
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
