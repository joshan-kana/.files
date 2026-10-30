_: {
  nixpkgs.overlays = [
    (
      _final: prev:
      prev.lib.optionalAttrs (prev.stdenv.hostPlatform.isDarwin && prev.stdenv.hostPlatform.isAarch64) {
        ollama =
          (import ../../lib/mac-app.nix
            {
              inherit prev;
            }
            {
              token = "ollama-app";
              updateDir = "ollama";
              release = {
                version = "0.40.13";
                hash = "sha256-2jGJ+HA00iS+sHCNd7lRgLwDhy9uJp1ZvYiKIWBVxYo=";
              };
              pname = "ollama";
              appName = "Ollama.app";
              homepage = "https://ollama.com/";
              license = prev.lib.licenses.mit;
              url = r: "https://github.com/ollama/ollama/releases/download/v${r.version}/Ollama-darwin.zip";
              unpacker = prev.unzip;
            }
          ).overrideAttrs
            (old: {
              postInstall = (old.postInstall or "") + ''
                mkdir -p "$out/bin" "$out/lib"
                ln -s ../Applications/Ollama.app/Contents/Resources/ollama "$out/bin/ollama"
                ln -s ../Applications/Ollama.app/Contents/Resources "$out/lib/ollama"
              '';
              meta = old.meta // {
                mainProgram = "ollama";
              };
            });
      }
    )
  ];
}
