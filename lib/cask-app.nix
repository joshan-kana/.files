{ prev }:
{
  cask,
  updateFile ? "overlays/${cask}/default.nix",
  autoUpdate ? true,
  updateGroup ? null,
  updateScript ? [
    "${prev.python3}/bin/python3"
    "${../scripts/update-cask.py}"
    cask
    updateFile
  ]
  ++ prev.lib.optional (release ? hashes) "--arch-hashes",
  release,
  ...
}@args:
let
  versions = prev.lib.splitString "," release.version;
in
import ./mac-app.nix { inherit prev; } (
  builtins.removeAttrs args [
    "cask"
    "updateFile"
    "autoUpdate"
    "updateGroup"
    "updateScript"
  ]
  // {
    release = builtins.removeAttrs release [ "hashes" ] // {
      version = builtins.head versions;
      inherit versions;
      hash = if release ? hashes then release.hashes.${prev.stdenv.hostPlatform.system} else release.hash;
    };
    passthru = {
      inherit autoUpdate updateScript;
      updateFilename = updateFile;
    }
    // prev.lib.optionalAttrs (updateGroup != null) { inherit updateGroup; };
  }
)
