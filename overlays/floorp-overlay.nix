_: {
  nixpkgs.overlays = [
    (_final: prev: {
      floorp-bin-unwrapped = prev.floorp-bin-unwrapped.overrideAttrs (
        old:
        let
          # Determine architecture-specific values
          archInfo =
            if prev.stdenv.isAarch64 then
              {
                arch = "aarch64";
                hash = "sha256-zvkZjEWMKFutIq0jW3DZHWH9jVwnk+71pNUI1LwaC8s=";
              }
            else if prev.stdenv.isx86_64 then
              {
                arch = "x86_64";
                hash = "sha256-51tgjjklC8B0g7wnNS3HhnXg08MZRXTmuWfFXy9EZ6E=";
              }
            else
              throw "Unsupported architecture for floorp";
        in
        {
          src = prev.fetchurl {
            url = "https://github.com/Floorp-Projects/Floorp/releases/download/v${old.version}/floorp-linux-${archInfo.arch}.tar.xz";
            inherit (archInfo) hash;
          };
        }
      );
    })
  ];
}
