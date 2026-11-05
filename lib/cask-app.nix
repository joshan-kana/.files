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
  ],
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
    release = release // {
      version = builtins.head versions;
      inherit versions;
    };
    passthru = {
      inherit autoUpdate updateScript;
      updateFilename = updateFile;
    }
    // prev.lib.optionalAttrs (updateGroup != null) { inherit updateGroup; };
  }
)
