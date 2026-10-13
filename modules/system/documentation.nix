{ lib, system, ... }:

let
  inherit (lib.systems.elaborate system) isLinux;
in
lib.optionalAttrs isLinux {
  documentation = {
    enable = true;
    man = {
      enable = true;
      cache.enable = true;
    };
  };
}
