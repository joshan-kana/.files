{ config, ... }:

{
  services.immich = {
    enable = true;
    host = config.dotfiles.server.lan.serverIp;
    openFirewall = true;
    mediaLocation = "${config.dotfiles.server.storage.dataRoot.path}/immich";
    group = config.dotfiles.server.storage.dataRoot.group.name;
  };
}
