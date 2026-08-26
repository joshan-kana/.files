{
  config,
  lib,
  ...
}:

let
  primaryUser = config.dotfiles.users.primary.name;
in
{
  users.users.${primaryUser} = {
    extraGroups = [ "docker" ];
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGMZdbT05P/naiv07J32DxHDOR5A1z8F9jijeBrDkXWV joshankana@gmail.com"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIG4kCJGHE5VF6YL3Y2almpG/0cl7+h2mMrSRONRXIhZr Shortcuts on Joshan’s iPhone"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIH2MhLVRuFAl9pssk8T3uxTr332TGoZMqjSoOLGudXpO Joshan's iPhone"
    ];
  };

  security.pam.sshAgentAuth = {
    enable = true;
    authorizedKeysFiles = [
      "/etc/sudo-authorized-key"
    ];
  };

  security.sudo = {
    extraConfig = ''
      Defaults:joshan noninteractive_auth
    '';
    wheelNeedsPassword = true;
  };

  systemd.tmpfiles.rules = [
    "f+ /etc/sudo-authorized-key 0444 root root - ${
      lib.concatStringsSep "\\n" [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIjtOri4c/7Nw3CMsv+ADMgepdVBTvtBlrTSJR+w5r7s joshan@nixos-server-sudo"
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIH2MhLVRuFAl9pssk8T3uxTr332TGoZMqjSoOLGudXpO Joshan's iPhone"
      ]
    }\\n"
  ];
}
