{ lib, ... }:

{
  dotfiles.scopes = {
    cli = {
      mpv.enable = lib.mkDefault false;
      xytz.enable = lib.mkDefault false;
      spotifyPlayer.enable = lib.mkDefault false;
      ncmpcpp.enable = lib.mkDefault false;
      cava.enable = lib.mkDefault false;
      ytDlp.enable = lib.mkDefault false;
      mediainfo.enable = lib.mkDefault false;
      clipboard.enable = lib.mkDefault false;
      esptool.enable = lib.mkDefault false;
      tio.enable = lib.mkDefault false;
      ollama.enable = lib.mkDefault false;
      bitwardenCli.enable = lib.mkDefault false;
    };
    virtualisation.children.enable = lib.mkDefault false;
  };
}
