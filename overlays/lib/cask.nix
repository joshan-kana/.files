{
  inputs,
  lib,
  token,
}:
let
  source = builtins.readFile (
    inputs.homebrew-cask + "/Casks/${builtins.substring 0 1 token}/${token}.rb"
  );
  lines = lib.splitString "\n" source;
  matchFirst =
    pattern:
    let
      captures = builtins.filter (result: result != null) (map (line: builtins.match pattern line) lines);
    in
    if captures == [ ] then
      throw "Missing ${token} cask metadata: ${pattern}"
    else
      builtins.head (builtins.head captures);
  versionString = matchFirst "[[:space:]]*version \"([^\"]+)\".*";
  armHash = builtins.filter (x: x != null) (
    map (line: builtins.match "[[:space:]]*sha256 arm:[[:space:]]*\"([a-f0-9]+)\".*" line) lines
  );
  hash =
    if armHash != [ ] then
      builtins.head (builtins.head armHash)
    else
      matchFirst "[[:space:]]*sha256[[:space:]]+\"([a-f0-9]+)\".*";
in
{
  version = builtins.head (lib.splitString "," versionString);
  versions = lib.splitString "," versionString;
  hash = builtins.convertHash {
    inherit hash;
    hashAlgo = "sha256";
    toHashFormat = "sri";
  };
}
