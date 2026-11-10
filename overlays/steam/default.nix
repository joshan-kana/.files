_: {
  nixpkgs.overlays = [
    (
      _final: prev:
      prev.lib.optionalAttrs prev.stdenv.hostPlatform.isDarwin {
        steam = import ../../lib/mac-app.nix { inherit prev; } {
          pname = "steam";
          release = {
            version = "6.1";
            build = "984652b88a9737e3f4e77c656d9ffa67d5042c2c";
            hash = "sha256-i/TOi0vLxQ9kKYjJVVWfYF56h3NyEW56Kz/RNVAEvts=";
          };
          appName = "Steam.app";
          homepage = "https://store.steampowered.com/";
          license = prev.lib.licenses.unfree;
          unpacker = prev.unzip;
          unpackCmd = ''unzip -q "$curSrc" && tar -xzf SteamMacBootstrapper.tar.gz'';
          passthru = rec {
            autoUpdate = true;
            updateFilename = "overlays/steam/default.nix";
            updateUrl = "https://formulae.brew.sh/api/cask/steam.json";
            updateScript = [
              "${prev.python3}/bin/python3"
              "-c"
              ''
                import base64, json, pathlib, re, sys, urllib.request

                request = urllib.request.Request(sys.argv[1], headers={"User-Agent": "nix-update"})
                release = json.load(urllib.request.urlopen(request, timeout=30))
                version, _, build = release["version"].split(",")
                digest = release["sha256"]
                if not re.fullmatch("[a-f0-9]{40}", build) or not re.fullmatch("[a-f0-9]{64}", digest):
                    sys.exit("Invalid Steam bootstrapper metadata")

                path = pathlib.Path(sys.argv[2])
                source = path.read_text()
                values = {"version": version, "build": build, "hash": "sha256-" + base64.b64encode(bytes.fromhex(digest)).decode()}
                for name, value in values.items():
                    source, count = re.subn(rf'(?m)^(\s*{name} = ")[^"]+(";)$', lambda match: match[1] + value + match[2], source)
                    if count != 1:
                        sys.exit(f"Expected exactly one {name} field in {path}")
                path.write_text(source)
              ''
              updateUrl
              updateFilename
            ];
          };
          url = r: "https://client-update.steamstatic.com/appdmg_osx.zip.${r.build}";
        };
      }
    )
  ];
}
