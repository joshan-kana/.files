_: {
  nixpkgs.overlays = [
    (
      _final: prev:
      prev.lib.optionalAttrs prev.stdenv.hostPlatform.isDarwin {
        raycast = import ../../lib/mac-app.nix { inherit prev; } {
          release = {
            version = "2.14.0.0";
            hash = "sha256-LRZjKGRAmAnuho+m2Gv2MWw5Mbiu1X4x7K8Cj3SK7ik=";
          };
          pname = "raycast";
          appName = "Raycast.app";
          homepage = "https://raycast.com";
          license = prev.lib.licenses.unfree;
          unpacker = prev._7zz;
          unpackCmd = ''
            7zz x -sns- -snld20 -spd -y "$curSrc"
          '';
          passthru = rec {
            autoUpdate = true;
            updateUrl = "https://formulae.brew.sh/api/cask/raycast.json";
            updateRegex = ''"version"\s*:\s*"([^"]+)"'';
            updateScript = [
              "${prev.python3}/bin/python3"
              "${../../scripts/update-version.py}"
              updateFilename
              prev.stdenv.hostPlatform.system
            ];
            updateFilename = "overlays/raycast/default.nix";
          };
          url =
            r: "https://x.raycast-releases.com/download?platform=macos&architecture=arm64&version=${r.version}";
        };
      }
    )
  ];
}
