_: {
  nixpkgs.overlays = [
    (
      _final: prev:
      prev.lib.optionalAttrs prev.stdenv.hostPlatform.isDarwin {
        vlc = import ../../lib/mac-app.nix { inherit prev; } {
          pname = "vlc";
          release = {
            version = "3.0.24";
            hash = "sha256-ZKidk83TCw6XExdD4kY3PbgtaCbqiC0mXUbXSxNtorc=";
          };
          appName = "VLC.app";
          homepage = "https://www.videolan.org/vlc/";
          license = prev.lib.licenses.gpl2Plus;
          passthru = rec {
            autoUpdate = true;
            updateUrl = "https://formulae.brew.sh/api/cask/vlc.json";
            updateRegex = ''"version"\s*:\s*"([^"]+)"'';
            updateScript = [
              "${prev.python3}/bin/python3"
              "${../../scripts/update-version.py}"
              updateFilename
              prev.stdenv.hostPlatform.system
            ];
            updateFilename = "overlays/vlc/default.nix";
          };
          url = r: "https://get.videolan.org/vlc/${r.version}/macosx/vlc-${r.version}-arm64.dmg";
        };
      }
    )
  ];
}
