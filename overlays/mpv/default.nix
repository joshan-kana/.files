let
  package =
    { pkgs }:
    pkgs.libplacebo.overrideAttrs (old: {
      passthru = (old.passthru or { }) // {
        dotfilesUpdateMode = "branch";
      };
      version = "7.373.0";
      src = pkgs.fetchFromGitHub {
        owner = "haasn";
        repo = "libplacebo";
        rev = "1930e6bf704e5631e6d2fd8cdd94b2fdcb94cdfe";
        hash = "sha256-eyHULuy8jM3qdDGQNQhfr3992gkBwfdO7sPULGxwEgU=";
      };
    });
in
_: {
  dotfiles.updatePolicy."libplacebo-mpv" = "manual";
  nixpkgs.overlays = [
    (final: prev: {
      libplacebo-mpv = package { pkgs = prev; };
      mpv-unwrapped = prev.mpv-unwrapped.override { libplacebo = final.libplacebo-mpv; };
      mpv = prev.mpv.override { inherit (final) mpv-unwrapped; };
    })
  ];
}
