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
              release = {
                version = "0.40.15";
                hash = "sha256-3jKYuYl4KEgMNhwQHj79LTxJnQiILI7pct9SQGSrw9s=";
              };
              pname = "ollama";
              appName = "Ollama.app";
              homepage = "https://ollama.com/";
              license = prev.lib.licenses.mit;
              passthru = {
                autoUpdate = true;
                updateUrl = "https://github.com/ollama/ollama";
                updateGithubReleases = true;
                updateFilename = "overlays/ollama/default.nix";
              };
              url = r: "https://github.com/ollama/ollama/releases/download/v${r.version}/Ollama-darwin.zip";
              unpacker = prev.unzip;
            }
          ).overrideAttrs
            (old: {
              postInstall = (old.postInstall or "") + ''
                mkdir -p "$out/bin" "$out/lib"
                # Replace the generic app launcher with the real CLI for `serve` and MLX.
                rm "$out/bin/ollama"
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
