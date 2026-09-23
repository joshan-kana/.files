{ config, lib, ... }:

let
  inherit (config.dotfiles.server.storage) appData;
  matterStateDir = "${appData.root}/matter-server";
in
{
  users.users.matter-server = {
    isSystemUser = true;
    group = appData.group.name;
  };

  services.matter-server = {
    enable = true;
    extraArgs.vendorid = 65521; # 0xFFF1, used by the existing Matter fabric.
  };

  systemd.services.matter-server.serviceConfig = {
    DynamicUser = lib.mkForce false;
    User = "matter-server";
    # StateDirectory sources are relative to /var/lib; keep the semantic path above absolute.
    StateDirectory = lib.mkForce [ "${lib.removePrefix "/var/lib/" matterStateDir}:matter-server" ];
  };
}
