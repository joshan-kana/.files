{ lib, ... }:

let
  appModules = {
    attic = ./attic;
    chatgpt-shell-access = ./chatgpt-shell-access;
    gitea = ./gitea;
    home-assistant = ./home-assistant;
    immich = ./immich;
    matter-server = ./matter-server;
    n8n = ./n8n;
    onedev = ./onedev;
    openclaw = ./openclaw;
    paperless = ./paperless;
  };

  mkAppModule =
    name: module:
    { config, ... }@args:
    {
      options.dotfiles.server.apps.${name}.enable = (lib.mkEnableOption "${name} server app") // {
        default = true;
      };

      config = lib.mkIf config.dotfiles.server.apps.${name}.enable (import module args);
    };
in
{
  imports = lib.mapAttrsToList mkAppModule appModules;
}
