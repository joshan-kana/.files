_:
let
  version = "0.1.16";
  sources = {
    aarch64-darwin = {
      asset = "macos-aarch64";
      hash = "sha256-mQAIderZMzoz9ctgJ0zNnPnT5HNg8DYTpGcpUQXHHAQ=";
    };
    aarch64-linux = {
      asset = "linux-aarch64";
      hash = "sha256-7+708XWbDokA8gXCwisUKHoRL4dEBlObTqGzviS3NjE=";
    };
    x86_64-linux = {
      asset = "linux-x86_64";
      hash = "sha256-KC0mMhlrI4IGz+Zr+2HA+vKZyhyRhDvQdlIbvjZXEhY=";
    };
  };
in
{
  nixpkgs.overlays = [
    (
      _final: prev:
      let
        inherit (prev) lib;
        system = prev.stdenv.hostPlatform.system;
        source = sources.${system};
        pname = "herdr-app";
        homepage = "https://herdr.dev/";
        license = lib.licenses.asl20;
        releases = "https://releases.herdr.dev/app";
        url = "${releases}/${version}/${pname}-${source.asset}.tar.gz";
        passthru = rec {
          autoUpdate = true;
          updateGroup = pname;
          updateUrl = "${releases}/latest.json";
          updateRegex = ''"version"\s*:\s*"([^"]+)"'';
          updateFilename = "overlays/${pname}/default.nix";
          updateScript = [
            "${prev.python3}/bin/python3"
            "${../../scripts/update-version.py}"
            updateFilename
            system
          ];
        };
      in
      lib.optionalAttrs (builtins.hasAttr system sources) {
        herdr-app =
          if prev.stdenv.hostPlatform.isDarwin then
            import ../../lib/mac-app.nix { inherit prev; } {
              inherit
                pname
                homepage
                license
                passthru
                ;
              release = {
                inherit version;
                inherit (source) hash;
              };
              appName = "Herdr.app";
              unpacker = prev.libarchive;
              unpackCmd = ''bsdtar -xf "$curSrc"'';
              url = _: url;
            }
          else
            prev.stdenv.mkDerivation {
              inherit pname version passthru;
              src = prev.fetchurl {
                inherit url;
                inherit (source) hash;
              };
              nativeBuildInputs = [
                prev.autoPatchelfHook
                prev.makeWrapper
              ];
              buildInputs = with prev; [
                fontconfig
                libxkbcommon
                stdenv.cc.cc.lib
                vulkan-loader
                libxcb
              ];
              dontBuild = true;
              installPhase = ''
                runHook preInstall
                install -Dm755 ${pname} "$out/bin/${pname}"
                install -Dm644 ${pname}.svg "$out/share/icons/hicolor/scalable/apps/${pname}.svg"
                install -Dm644 LICENSE "$out/share/licenses/${pname}/LICENSE"
                install -Dm644 THIRD-PARTY-NOTICES "$out/share/licenses/${pname}/THIRD-PARTY-NOTICES"
                install -Dm644 /dev/stdin "$out/share/applications/${pname}.desktop" <<DESKTOP
                [Desktop Entry]
                Type=Application
                Name=Herdr
                Comment=Persistent terminals and coding agents
                Exec=${pname}
                Icon=${pname}
                Terminal=false
                Categories=Development;
                StartupWMClass=${pname}
                DESKTOP
                wrapProgram "$out/bin/${pname}" --prefix LD_LIBRARY_PATH : "${
                  lib.makeLibraryPath [ prev.vulkan-loader ]
                }"
                runHook postInstall
              '';
              meta = {
                description = "Native desktop client for Herdr Core terminals";
                inherit homepage license;
                platforms = builtins.attrNames sources;
                mainProgram = pname;
                sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
              };
            };
      }
    )
  ];
}
