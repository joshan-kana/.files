_: {
  nixpkgs.overlays = [
    (final: prev: {
      libplacebo-mpv = import ./package.nix { pkgs = prev; };
      mpv-unwrapped = prev.mpv-unwrapped.override { libplacebo = final.libplacebo-mpv; };
      mpv = prev.mpv.override { inherit (final) mpv-unwrapped; };
    })
  ];
}
