_:
let
  release = {
    version = "0.2026.11.03.17.08.stable_00";
    hash = "sha256-ip12Il6FHvL1yR/Zc+xUJagMCSgNBngI3D7RBfitdr4=";
  };
  linuxHashes = {
    x86_64-linux = "sha256-JnwZ0z5nBbWPWVLRyS32VhMZ5nSl8ULgmKSubMsaZWE=";
    aarch64-linux = "sha256-R+pAJ3/qYcuQyKPju0n6lxeOFXmnS2Q45GHXJ43grDc=";
  };
in
{
  nixpkgs.overlays = [
    (
      _final: prev:
      let
        system = prev.stdenv.hostPlatform.system;
        isDarwin = prev.stdenv.hostPlatform.isDarwin;
      in
      prev.lib.optionalAttrs
        (builtins.elem system [
          "aarch64-darwin"
          "x86_64-darwin"
          "x86_64-linux"
          "aarch64-linux"
        ])
        {
          warp-terminal = prev.warp-terminal.overrideAttrs (old: {
            inherit (release) version;
            src = prev.fetchurl {
              url =
                if isDarwin then
                  "https://releases.warp.dev/stable/v${release.version}/Warp.dmg"
                else
                  "https://releases.warp.dev/stable/v${release.version}/warp-terminal-v${release.version}-1-${
                    if prev.stdenv.hostPlatform.isAarch64 then "aarch64" else "x86_64"
                  }.pkg.tar.zst";
              hash = if isDarwin then release.hash else linuxHashes.${system};
            };
            passthru =
              (builtins.removeAttrs (old.passthru or { }) [ "updateScript" ])
              // {
                autoUpdate = isDarwin;
                updateGroup = "warp-terminal";
                updateFilename = "overlays/warp/default.nix";
              }
              // prev.lib.optionalAttrs isDarwin {
                updateScript = [
                  "${prev.python3}/bin/python3"
                  "${../../scripts/update-cask.py}"
                  "warp"
                  "overlays/warp/default.nix"
                ];
              };
          });
        }
    )
  ];
}
