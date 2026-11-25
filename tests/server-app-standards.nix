{ configuration, inputs }:

let
  inherit (inputs.nixpkgs) lib;
  cfg = configuration.config;
  alternate =
    (configuration.extendModules {
      modules = [
        {
          dotfiles.server = {
            storage = {
              appData = {
                root = "/var/lib/alternate-apps";
                group.name = "alternate-editors";
              };
              dataRoot.path = "/srv/alternate-vault";
            };
            lan.gateway = "192.168.1.254";
          };
          dotfiles.services = {
            attic.port = 18080;
            n8n.port = 15678;
            ntfy.port = 12586;
          };
          dotfiles.backups.secrets.credentialsDir = "/var/lib/alternate-credentials";
        }
      ];
    }).config;
  inherit (alternate.dotfiles.server) storage;
  incomplete = "${storage.dataRoot.path}/media/downloads/incomplete";
  rcloneConfig = alternate.dotfiles.backups.secrets.rcloneConfigFile;
  tailscaleInterface = cfg.services.tailscale.interfaceName;
  tailscaleFirewall = lib.attrByPath [ tailscaleInterface ] { } cfg.networking.firewall.interfaces;

  requiredSecretUnits = [
    "atticd"
    "chatgpt-shell-access"
    "docker-n8n"
    "openclaw-gateway"
  ]
  ++ lib.filter (lib.hasPrefix "matrix-bridge-") (builtins.attrNames cfg.systemd.services);

  hasRequiredPathAssertion =
    unit: lib.attrByPath [ unit "unitConfig" "AssertPathExists" ] null cfg.systemd.services != null;
in
assert lib.elem tailscaleInterface cfg.networking.firewall.trustedInterfaces;
assert lib.attrByPath [ "allowedTCPPorts" ] [ ] tailscaleFirewall == [ ];
assert lib.attrByPath [ "allowedUDPPorts" ] [ ] tailscaleFirewall == [ ];
assert builtins.all hasRequiredPathAssertion requiredSecretUnits;
assert builtins.all (
  name: lib.elem "docker.service" cfg.systemd.services."docker-${name}".requires
) (builtins.attrNames cfg.virtualisation.oci-containers.containers);
assert lib.elem "d ${cfg.dotfiles.server.secretsDir} 0700 root root - -" cfg.systemd.tmpfiles.rules;
assert lib.elem "Z ${cfg.dotfiles.server.secretsDir} ~0700 root root - -"
  cfg.systemd.tmpfiles.rules;
assert
  alternate.fileSystems.${incomplete}.device == "${storage.dataRoot.poolName}/downloads-incomplete";
assert alternate.services.transmission.settings.incomplete-dir == incomplete;
assert alternate.systemd.services.transmission.unitConfig.ConditionPathIsMountPoint == incomplete;
assert alternate.users.users.adguardhome.group == storage.appData.group.name;
assert
  alternate.systemd.services.adguardhome.serviceConfig.StateDirectory
  == "alternate-apps/adguard/conf";
assert
  alternate.systemd.services.technitium-dns-server.serviceConfig.StateDirectory
  == "alternate-apps/technitium";
assert
  alternate.systemd.services.matter-server.serviceConfig.StateDirectory
  == [ "alternate-apps/matter-server:matter-server" ];
assert alternate.services.restic.backups.apps.rcloneConfigFile == rcloneConfig;
assert alternate.services.atticd.settings.listen == "0.0.0.0:18080";
assert lib.elem "http://nixos-server.home:18080/dotfiles" alternate.nix.settings.substituters;
assert alternate.services.ntfy-sh.settings."base-url" == "http://nixos-server.home:12586";
assert
  alternate.services.ntfy-sh.settings."listen-http"
  == "${alternate.dotfiles.server.lan.serverIp}:12586";
assert
  alternate.virtualisation.oci-containers.containers.n8n.ports == [
    "${alternate.dotfiles.server.lan.serverIp}:15678:5678"
  ];
assert lib.elem "dropbox-rclone:${rcloneConfig}"
  alternate.systemd.services.agentgateway.serviceConfig.LoadCredential;
assert
  builtins.head alternate.dotfiles.server.lan.dns.fallbackServers
  == alternate.dotfiles.server.lan.gateway;
true
