{ dotfilesPath, profileName, ollamaUrl, ... }:

{
  environment.sessionVariables = {
    DOTFILES = dotfilesPath;
    FLK_PROFILE = profileName;
    OLLAMA_URL = ollamaUrl;
  };
}