{
  modulesPath,
  lib,
  config,
  ...
}:
{
  imports = [
    "${modulesPath}/virtualisation/lxc-container.nix"
    /etc/nixos/orbstack.nix
  ];

  # In LXC containers we don't have Wi‑Fi, and `/etc` may be read-only.
  # Avoid starting wpa_supplicant (it tries to create /etc/wpa_supplicant/*).
  systemd.services.wpa_supplicant.enable = lib.mkIf (config.boot.isContainer or false) (
    lib.mkForce false
  );
  networking.wireless.enable = lib.mkIf (config.boot.isContainer or false) (lib.mkForce false);

  # OrbStack containers often come up with NetworkManager running but no
  # persisted autoconnect profile, so networking only works after `nmtui`
  # → “Activate a connection”. Ensure a wired DHCP profile exists.
  networking.networkmanager.ensureProfiles = lib.mkIf (config.boot.isContainer or false) {
    profiles."Wired connection 1" = {
      connection = {
        id = "Wired connection 1";
        type = "ethernet";
        interface-name = "eth0";
        autoconnect = true;
        # Prefer this profile over any auto-generated 'eth0' profile.
        autoconnect-priority = 100;
      };
      ipv4 = {
        method = "auto";
      };
      ipv6 = {
        method = "auto";
      };
    };

    # NetworkManager may auto-create an 'eth0' connection that shows up as
    # active in `nmtui` but doesn't actually result in working connectivity.
    # Prevent it from winning autoconnect on boot.
    profiles."eth0" = {
      connection = {
        id = "eth0";
        type = "ethernet";
        interface-name = "eth0";
        autoconnect = false;
      };
      ipv4.method = "disabled";
      ipv6.method = "disabled";
    };
  };
}
