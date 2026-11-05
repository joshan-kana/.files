{ prev }:
{
  cask,
  updateDir ? cask,
  autoUpdate ? true,
  updateGroup ? null,
  updateScript ? [
    "${prev.python3}/bin/python3"
    "${../scripts/update-cask.py}"
    cask
    updateDir
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
    "updateDir"
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
    }
    // prev.lib.optionalAttrs (updateGroup != null) { inherit updateGroup; };
  }
)
