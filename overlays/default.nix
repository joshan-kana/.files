# Central registry for package definitions, version pins, and compatibility patches.
# Add a package's overlay here rather than importing it from a host or feature module.
{
  imports = [
    ./bottles
    ./brave
    ./comin
    ./configarr
    ./gh-dash
    ./nixos-options-doc
    ./tuicr
    ./webhook
    ./arc
    ./arduino-ide
    ./chatgpt
    ./bambu-studio
    ./cryptomator
    ./hammerspoon
    ./heroic
    ./iterm2
    ./jellyfin-mpv-shim
    ./linear
    ./notion
    ./open-webui
    ./prusaslicer
    ./qmk-toolbox
    ./reaper
    ./vial
    ./determinate-nix
    ./hermes-agent
    ./matrix-bridges
    ./ncmpcpp
    ./openclaw
    ./parallels-tools
    ./zen-browser
  ];
}
