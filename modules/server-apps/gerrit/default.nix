{
  config,
  lib,
  pkgs,
  ...
}:

let
  inherit (config.dotfiles) server;
  httpPort = 8787;
  sshPort = 29418;
  oauthCredentials = "${server.secretsDir}/gerrit-github-oauth.conf";
in
{
  services.gerrit = {
    enable = true;
    plugins = [
      (pkgs.fetchurl {
        name = "gerrit-oauth-provider.jar";
        url = "https://gerrit-ci.gerritforge.com/job/plugin-oauth-bazel-stable-3.14/1/artifact/bazel-bin/plugins/oauth/oauth.jar";
        hash = "sha256-R6IahUTXS294nnxXB1WI4gREg5sqUn6sahtKfvaNfZI=";
      })
    ];
    serverId = "dec01ec9-55a7-4fed-bb8b-08278d06cf51";
    listenAddress = "${server.lan.serverIp}:${toString httpPort}";

    settings = {
      auth.type = "OAUTH";
      gerrit.canonicalWebUrl = "http://nixos-server.home:${toString httpPort}/";
      sshd.listenAddress = "${server.lan.serverIp}:${toString sshPort}";
      sshd.advertisedAddress = "nixos-server.home:${toString sshPort}";
    };
  };

  systemd.services.gerrit = {
    unitConfig.AssertPathExists = [ oauthCredentials ];
    serviceConfig.LoadCredential = [ "github-oauth:${oauthCredentials}" ];

    preStart = lib.mkAfter ''
      credentials="$CREDENTIALS_DIRECTORY/github-oauth"
      for field in client-id client-secret; do
        value="$(git config --file "$credentials" --get "plugin.gerrit-oauth-provider-github-oauth.$field")"
        test -n "$value"
        git config --file etc/secure.config --replace-all "plugin.gerrit-oauth-provider-github-oauth.$field" "$value"
      done
      if ! git config --file etc/secure.config --get auth.tokenEncryptionKey >/dev/null; then
        git config --file etc/secure.config auth.tokenEncryptionKey "$(${pkgs.openssl}/bin/openssl rand -base64 32)"
      fi
    '';
  };

  networking.firewall.interfaces.${server.lan.interface}.allowedTCPPorts = [
    httpPort
    sshPort
  ];

  services.restic.backups.apps.paths = [ "/var/lib/gerrit" ];
  virtualisation.vmVariant.services.gerrit.enable = lib.mkForce false;
}
