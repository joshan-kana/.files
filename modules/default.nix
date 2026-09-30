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
    Self-hosted server applications and app-owned infrastructure.
  */
  serverApps = import ./server-apps;

  /**
    Local snapshot, off-site backup, and recovery-support infrastructure.
  */
  backups = import ./backups;

  profiles = import ./profiles;
}
