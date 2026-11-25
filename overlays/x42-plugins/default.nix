_: {
  nixpkgs.overlays = [
    (
      _final: prev:
      prev.lib.optionalAttrs (prev.stdenv.hostPlatform.system == "aarch64-linux") {
        x42-plugins = prev.x42-plugins.overrideAttrs (old: {
          # These Makefiles unconditionally enable x86 SSE compiler flags.
          patchPhase = old.patchPhase + ''
            for plugin in controlfilter mididebug midigen midimap onsettrigger stereoroute; do
              substituteInPlace "$plugin.lv2/Makefile" \
                --replace-fail '-msse -msse2 -mfpmath=sse ' ""
            done
          '';
          meta = old.meta // {
            platforms = old.meta.platforms ++ [ "aarch64-linux" ];
          };
        });
      }
    )
  ];
}
