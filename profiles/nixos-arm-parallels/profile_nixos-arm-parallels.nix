{
  dotfilesPath,
  profileName,
  ollamaUrl,
  nixosRebuildFlags,
  ...
}:

{
  environment.sessionVariables = {
    DOTFILES = dotfilesPath;
    FLK_PROFILE = profileName;
    OLLAMA_URL = ollamaUrl;
    NIXOS_REBUILD_FLAGS = nixosRebuildFlags;
  };
}
