{ ... }:

{
  imports = [
    ./home-assistant.nix
    ./matter-server.nix
    ./n8n.nix
    ./openclaw.nix
    ./open-webui.nix
  ];
}
