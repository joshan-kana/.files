{
  config,
  lib,
  ...
}:

let
  inherit (config.dotfiles) server;

  service = {
    ip = server.lan.serverIp;
    port = 2586;
    stateDir = "${server.storage.appData.root}/ntfy";
  };
in
{
  services.ntfy-sh = {
    enable = true;

    settings = {
      "base-url" = config.dotfiles.services.ntfy.url;
      "listen-http" = "${service.ip}:${toString service.port}";
      "auth-file" = "${service.stateDir}/user.db";
      "auth-default-access" = "deny-all";
      "cache-file" = "${service.stateDir}/cache.db";
      "attachment-cache-dir" = "${service.stateDir}/attachments";
      "enable-login" = false;
      "enable-signup" = false;
    };
  };

  networking.firewall.interfaces.${server.lan.interface}.allowedTCPPorts = [ service.port ];

  users.users.ntfy-sh = lib.mkIf config.services.ntfy-sh.enable {
    extraGroups = [ server.storage.appData.group.name ];
  };

  systemd = {
    services.ntfy-sh.serviceConfig = {
      StateDirectory = lib.mkForce [ ];
      ReadWritePaths = [ service.stateDir ];
    };

    tmpfiles.rules = [
      "d ${service.stateDir} 0750 ntfy-sh ntfy-sh - -"
      "d ${service.stateDir}/attachments 0750 ntfy-sh ntfy-sh - -"
    ];
  };

  virtualisation.vmVariant.services.ntfy-sh.enable = lib.mkForce false;
}
