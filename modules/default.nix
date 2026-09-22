{
  /**
    Core identity, locale, documentation, and compatibility policy shared by hosts.
  */
  system = import ./system;

  /**
    Nix daemon, registry, cache, builder, and repository-tooling policy.
  */
  nix = import ./nix;

  /**
    Shared visual theme policy and assets consumed by system and home configuration.
  */
  theme = import ./theme;

  /**
    Command-line programs, shells, aliases, and terminal-oriented workflows.
  */
  cli = import ./cli;

  /**
    Shared connectivity, discovery, SSH, and host-network policy.
  */
  networking = import ./networking;

  /**
    Shared support for running and integrating AppImage applications.
  */
  appimage = import ./appimage;

  /**
    Shared audio stack and audio-device policy.
  */
  audio = import ./audio;

  /**
    Containers, virtual machines, and other virtualisation capabilities.
  */
  virtualisation = import ./virtualisation;

  /**
    Graphical-session infrastructure and desktop environments.
  */
  desktop = import ./desktop;

  /**
    Desktop applications that are independent of a specific desktop environment.
  */
  desktopApps = import ./desktop-apps;

  /**
    Self-hosted server applications and their app-owned infrastructure.

    Each application scope owns the complete app-specific system consequence of
    enabling that application: service/container configuration, persistent-state
    wiring, secrets references, users/groups, permissions, firewall rules,
    backups, and runtime glue. Shared infrastructure remains in its shared scope.

    Runtime secrets are files outside the Nix store. Required secrets should make
    an enabled service fail clearly when absent rather than silently disabling the
    service. Persistent application state normally belongs under the configured
    application-data root; bulk user data belongs under the configured bulk-data
    root.

    Prefer native NixOS modules when they cleanly express the deployment. Do not
    add a second server-app abstraction layer merely to make applications look
    uniform.
  */
  serverApps = import ./server-apps;

  /**
    Local snapshot, off-site backup, and recovery-support infrastructure.
  */
  backups = import ./backups;

  profiles = import ./profiles;
}
