{ configuration, inputs }:

let
  inherit (inputs.nixpkgs) lib;
  cfg = configuration.config;
  tailscaleInterface = cfg.services.tailscale.interfaceName;
  tailscaleFirewall = lib.attrByPath [ tailscaleInterface ] { } cfg.networking.firewall.interfaces;

  requiredSecretUnits = [
    "atticd"
    "chatgpt-shell-access"
    "docker-n8n"
    "docker-openclaw"
  ]
  ++ lib.filter (lib.hasPrefix "matrix-bridge-") (builtins.attrNames cfg.systemd.services);

  hasRequiredPathAssertion =
    unit: lib.attrByPath [ unit "unitConfig" "AssertPathExists" ] null cfg.systemd.services != null;
in
assert lib.elem tailscaleInterface cfg.networking.firewall.trustedInterfaces;
assert lib.attrByPath [ "allowedTCPPorts" ] [ ] tailscaleFirewall == [ ];
assert lib.attrByPath [ "allowedUDPPorts" ] [ ] tailscaleFirewall == [ ];
assert builtins.all hasRequiredPathAssertion requiredSecretUnits;
true
