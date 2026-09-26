{
  config,
  lib,
  pkgs,
  ...
}:

let
  githubWebhookSecret = "${config.dotfiles.server.secretsDir}/comin-webhook-secret";
  topic = "${config.dotfiles.services.ntfy.url}/comin";
in
{
  enable = false;

  # ntfy is private to LAN/Tailscale, and this topic only triggers a safe fetch.
  services.ntfy-sh.settings."auth-access" = [ "*:comin:read-write" ];

  services.webhook = {
    enable = true;
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

    hooksTemplated.comin = ''
      {
        "id": "comin",
        "execute-command": "${lib.getExe pkgs.ntfy-sh}",
        "pass-arguments-to-command": [
          {"source": "string", "name": "publish"},
          {"source": "string", "name": "--quiet"},
          {"source": "string", "name": "${topic}"}
        ],
        "http-methods": ["POST"],
        "trigger-rule": {
          "and": [
            {
              "match": {
                "type": "payload-hmac-sha256",
                "secret": "{{ credential "github-webhook-secret" | js }}",
                "parameter": {
                  "source": "header",
                  "name": "X-Hub-Signature-256"
                }
              }
            },
            {
              "match": {
                "type": "value",
                "value": "refs/heads/main",
                "parameter": {
                  "source": "payload",
                  "name": "ref"
                }
              }
            }
          ]
        }
      }
    '';
  };

  systemd.services = {
    webhook = {
      after = [ "ntfy-sh.service" ];
      unitConfig.AssertPathExists = [ githubWebhookSecret ];
      serviceConfig.LoadCredential = [
        "github-webhook-secret:${githubWebhookSecret}"
      ];
    };

    tailscale-funnel-comin = {
      description = "Expose the authenticated Comin webhook through Tailscale Funnel";
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
          --set-path=/hooks/comin \
          http://127.0.0.1:9000/hooks/comin
      '';
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
    };
  };
}
