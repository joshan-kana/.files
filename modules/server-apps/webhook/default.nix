{
  config,
  pkgs,
  ...
}:

{
  nixpkgs.overlays = (import ../../../overlays/webhook.nix { }).nixpkgs.overlays;

  services.webhook = {
    package = pkgs.webhook;
    ip = "127.0.0.1";
    extraArgs = [
      "-max-body-size"
      "26214400"
    ];
  };

  systemd.services.tailscale-funnel-webhooks = {
    description = "Expose the webhook receiver through Tailscale Funnel";
    after = [
      "tailscaled-autoconnect.service"
      "webhook.service"
    ];
    wants = [ "webhook.service" ];
    wantedBy = [ "tailscaled-autoconnect.service" ];
    script = ''
      ${config.services.tailscale.package}/bin/tailscale funnel \
        --bg \
        --yes \
        --https=443 \
        http://127.0.0.1:${toString config.services.webhook.port}
    '';
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
  };
}
