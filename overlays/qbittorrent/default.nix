_: {
  nixpkgs.overlays = [
    (
      _final: prev:
      prev.lib.optionalAttrs prev.stdenv.hostPlatform.isDarwin {
        qbittorrent = prev.qbittorrent.overrideAttrs (old: {
          # Remove once nixpkgs packages qBittorrent 5.3.0 or later.
          postPatch = (old.postPatch or "") + ''
            for source in src/gui/log/loglistview.cpp src/gui/optionsdialog.cpp; do
              grep -qxF '#ifdef Q_OS_MAC' "$source"
              sed -i 's/^#ifdef Q_OS_MAC$/#ifdef Q_OS_MACOS/' "$source"
            done
          '';
        });
      }
    )
  ];
}
