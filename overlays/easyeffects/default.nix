_: {
  nixpkgs.overlays = [
    (
      final: prev:
      prev.lib.optionalAttrs prev.stdenv.hostPlatform.isLinux {
        easyeffects =
          if
            prev.lib.meta.availableOn prev.stdenv.hostPlatform final.x42-plugins
            && !(prev.lib.hasInfix (builtins.unsafeDiscardStringContext "${final.x42-plugins}/lib/lv2") prev.easyeffects.preFixup)
          then
            prev.easyeffects.overrideAttrs (old: {
              # Include x42 when the upstream wrapper omits an available plugin.
              preFixup =
                assert prev.lib.hasInfix ''--set LV2_PATH "'' old.preFixup;
                prev.lib.replaceStrings
                  [ ''--set LV2_PATH "'' ]
                  [ ''--set LV2_PATH "${final.x42-plugins}/lib/lv2:'' ]
                  old.preFixup;
            })
          else
            prev.easyeffects;
      }
    )
  ];
}
