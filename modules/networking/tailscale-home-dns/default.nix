_: {
  home = { lib, pkgs, ... }: {
    launchd.agents.tailscale-home-dns = {
      enable = true;
      config = {
        ProgramArguments = [
          (lib.getExe pkgs.tailscale-home-dns)
          "nixos-server"
        ];
        RunAtLoad = true;
        KeepAlive = true;
        ProcessType = "Background";
      };
    };
  };
}
