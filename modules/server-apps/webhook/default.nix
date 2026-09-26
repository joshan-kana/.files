{
  config,
  pkgs,
  ...
}:

{
  services.webhook = {
    package = pkgs.webhook.overrideAttrs (old: {
      patches = (old.patches or [ ]) ++ [
        (pkgs.fetchpatch {
          url = "https://github.com/mikelolasagasti/webhook/commit/2f9528ca1cc5a53c2e5bb9eaf60573a5c9171360.patch";
          hash = "sha256-MWps4IZ+OnCpbqKQnsPODHgr4LoY5/fqSxCCkdUjynE=";
        })
      ];
    });
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
