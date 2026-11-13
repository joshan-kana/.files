_:
let
  release = {
    version = "1.99.57";
    hash = "sha256-kik0sjPd7PpJqdxWKdQEaf2wstWcSVR2l+6g7sQIdxE=";
  };
  linuxHashes = {
    x86_64-linux = "sha256-jNFMV/f9bXnf2aJUUBdbVDihsRtWX/XQitmRtwLen9U=";
    aarch64-linux = "sha256-0F30+KjElAdSRoIMF4l6RpYU+HmTindVfwJf2nvmHbQ=";
  };
in
{
  nixpkgs.overlays = [
    (
      _final: prev:
      let
        system = prev.stdenv.hostPlatform.system;
        inherit (release) version;
        passthru = rec {
          autoUpdate = true;
          updateGroup = "brave";
          updateUrl = "https://brave-browser-apt-release.s3.brave.com/dists/stable/main/binary-amd64/Packages";
          updateRegex = ''(?ms)^Package: brave-browser\n(?:(?!^Package: ).)*?^Version: ([0-9]+(?:\.[0-9]+)+)$'';
          updateFilename = "overlays/brave/default.nix";
          updateScript = [
            "${prev.python3}/bin/python3"
            "${../../scripts/update-version.py}"
            updateFilename
            system
          ];
        };
      in
      prev.lib.optionalAttrs prev.stdenv.hostPlatform.isDarwin {
        brave = import ../../lib/mac-app.nix { inherit prev; } {
          inherit release passthru;
          pname = "brave";
          appName = "Brave Browser.app";
          homepage = "https://brave.com/";
          license = prev.lib.licenses.mpl20;
          url =
            r: "https://github.com/brave/brave-browser/releases/download/v${r.version}/Brave-Browser-arm64.dmg";
        };
      }
      //
        prev.lib.optionalAttrs
          (builtins.elem system [
            "x86_64-linux"
            "aarch64-linux"
          ])
          {
            brave =
              let
                deps = with prev; [
                  alsa-lib
                  at-spi2-atk
                  at-spi2-core
                  atk
                  cairo
                  cups
                  dbus
                  expat
                  fontconfig
                  freetype
                  gdk-pixbuf
                  glib
                  gtk3
                  gtk4
                  libdrm
                  libx11
                  libGL
                  libxkbcommon
                  libxscrnsaver
                  libxcomposite
                  libxcursor
                  libxdamage
                  libxext
                  libxfixes
                  libxi
                  libxrandr
                  libxrender
                  libxshmfence
                  libxtst
                  libuuid
                  libgbm
                  nspr
                  nss
                  pango
                  pciutils
                  pipewire
                  udev
                  wayland
                  libxcb
                  zlib
                  snappy
                  speechd-minimal
                  libkrb5
                  vulkan-loader
                  qt6.qtbase
                  libpulseaudio
                  libva
                ];
                rpath = prev.lib.makeLibraryPath deps + ":" + prev.lib.makeSearchPathOutput "lib" "lib64" deps;
              in
              prev.stdenv.mkDerivation {
                pname = "brave";
                inherit version;

                src = prev.fetchurl {
                  url = "https://github.com/brave/brave-browser/releases/download/v${version}/brave-browser_${version}_${
                    if system == "x86_64-linux" then "amd64" else "arm64"
                  }.deb";
                  hash = linuxHashes.${system};
                };

                nativeBuildInputs = with prev; [
                  dpkg
                  (buildPackages.wrapGAppsHook3.override { makeWrapper = buildPackages.makeShellWrapper; })
                ];
                buildInputs = with prev; [
                  glib
                  gsettings-desktop-schemas
                  gtk3
                  gtk4
                  adwaita-icon-theme
                ];
                dontConfigure = true;
                dontBuild = true;
                dontPatchELF = true;
                doInstallCheck = true;

                installPhase = ''
                  runHook preInstall

                  mkdir -p "$out/bin"
                  cp -R usr/share "$out/"
                  cp -R opt "$out/"

                  wrapper="$out/opt/brave.com/brave/brave-browser"
                  substituteInPlace "$wrapper" \
                    --replace-fail /bin/bash ${prev.stdenv.shell} \
                    --replace-fail CHROME_WRAPPER WRAPPER
                  ln -s "$wrapper" "$out/bin/brave"

                  for exe in "$out/opt/brave.com/brave/"{brave,chrome_crashpad_handler}; do
                    patchelf \
                      --set-interpreter "$(cat "$NIX_CC/nix-support/dynamic-linker")" \
                      --set-rpath "${rpath}" "$exe"
                  done

                  substituteInPlace "$out/share/applications/"{brave-browser,com.brave.Browser}.desktop \
                    --replace-fail /usr/bin/brave-browser-stable "$out/bin/brave"
                  substituteInPlace "$out/share/gnome-control-center/default-apps/brave-browser.xml" \
                    --replace-fail /opt/brave.com "$out/opt/brave.com"
                  substituteInPlace "$out/opt/brave.com/brave/default-app-block" \
                    --replace-fail /opt/brave.com "$out/opt/brave.com"

                  for size in 16 24 32 48 64 128 256; do
                    mkdir -p "$out/share/icons/hicolor/''${size}x''${size}/apps"
                    ln -s "$out/opt/brave.com/brave/product_logo_''${size}.png" \
                      "$out/share/icons/hicolor/''${size}x''${size}/apps/brave-browser.png"
                  done

                  ln -sf ${prev.lib.getLib prev.vulkan-loader}/lib/libvulkan.so.1 \
                    "$out/opt/brave.com/brave/libvulkan.so.1"
                  ln -sf ${prev.xdg-utils}/bin/xdg-settings "$out/opt/brave.com/brave/xdg-settings"
                  ln -sf ${prev.xdg-utils}/bin/xdg-mime "$out/opt/brave.com/brave/xdg-mime"

                  cat > "$out/opt/brave.com/brave/initial_preferences" <<'JSON'
                  ${builtins.toJSON { extensions.theme.system_theme = 2; }}
                  JSON

                  runHook postInstall
                '';

                preFixup = ''
                  gappsWrapperArgs+=(
                    --prefix LD_LIBRARY_PATH : ${rpath}
                    --prefix PATH : ${prev.lib.makeBinPath deps}
                    --suffix PATH : ${
                      prev.lib.makeBinPath [
                        prev.xdg-utils
                        prev.coreutils
                      ]
                    }
                    --set CHROME_WRAPPER brave
                    --add-flags '--enable-features=AcceleratedVideoDecodeLinuxGL,AcceleratedVideoEncoder'
                    --add-flags '--disable-features=OutdatedBuildDetector,UseChromeOSDirectVideoDecoder'
                    --add-flags "''${NIXOS_OZONE_WL:+''${WAYLAND_DISPLAY:+--ozone-platform-hint=auto}}"
                  )
                '';

                installCheckPhase = ''
                  "$out/opt/brave.com/brave/brave" --version
                '';

                inherit passthru;

                meta = with prev.lib; {
                  description = "Privacy-oriented web browser";
                  homepage = "https://brave.com/";
                  license = licenses.mpl20;
                  platforms = [
                    "x86_64-linux"
                    "aarch64-linux"
                  ];
                  mainProgram = "brave";
                  sourceProvenance = [ sourceTypes.binaryNativeCode ];
                };
              };
          }
    )
  ];
}
