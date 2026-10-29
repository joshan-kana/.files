# Central registry for package definitions, version pins, and compatibility patches.
# Add a package's overlay here rather than importing it from a host or feature module.
{ lib, ... }: {
  options.dotfiles.updatePolicy = lib.mkOption {
    type = lib.types.attrsOf (
      lib.types.enum [
        "auto"
        "manual"
      ]
    );
    default = { };
    description = "Routine or explicit-only updates for custom overlay packages.";
  };

  imports = [
    ./bottles
    ./brave
    ./comin
    ./configarr
    ./cosmic-noir-icons
    ./gh-dash
    ./gtksourceview
    ./nh
    ./polkit
    ./nixos-options-doc
    ./tuicr
    ./technitium-roaming
    ./webhook
    ./arc
    ./agentgateway
    ./arduino-ide
    ./chatgpt
    ./chatgpt-shell-mcp
    ./bambu-studio
    ./cryptomator
    ./hammerspoon
    ./heroic
    ./iterm2
    ./jellyfin-mpv-shim
    ./linear
    ./notion
    ./open-webui
    ./open-webui-computer
    ./python-matter-server
    ./prusaslicer
    ./qmk-toolbox
    ./reaper
    ./seerr
    ./vial
    ./determinate-nix
    ./hermes-agent
    ./matrix-bridges
    ./ncmpcpp
    ./mpv
    ./openclaw
    ./openai-tunnel-client
    ./parallels-tools
    ./zen-browser
    ./yabai
  ];
}
