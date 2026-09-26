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
  # ntfy is private to LAN/Tailscale, and this topic only triggers a safe fetch.
  services.ntfy-sh.settings."auth-access" = [ "*:comin:read-write" ];

  services.webhook.hooksTemplated.comin = ''
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

  systemd.services = {
    webhook = {
      after = [ "ntfy-sh.service" ];
      unitConfig.AssertPathExists = [ githubWebhookSecret ];
      serviceConfig.LoadCredential = [
        "github-webhook-secret:${githubWebhookSecret}"
      ];
    };

  };
}
