{
  config,
  lib,
  pkgs,
  system,
  ...
}:

let
  inherit (lib.systems.elaborate system) isDarwin isLinux;
  upstream = import ../../overlays/comin/source.nix;
  cominConfig = import "${upstream.outPath}/nix/comin-config.nix" { inherit config pkgs lib; };
in
{
  imports =
    lib.optionals isLinux [ upstream.nixosModules.comin ]
    ++ lib.optionals isDarwin [ upstream.darwinModules.comin ];

  options.services.comin.allowForcePush = lib.mkOption {
    type = lib.types.bool;
    default = false;
    description = ''
      Whether Comin may accept non-fast-forward updates to its main branch.
    '';
  };

  config =
    lib.optionalAttrs isLinux {
      systemd.services.comin = lib.mkIf config.services.comin.allowForcePush {
        environment.COMIN_ALLOW_FORCE_PUSH = "true";
      };
    }
    // lib.optionalAttrs isDarwin {
      # Keep the launchd job definition stable across switches. Changing its
      # plist during activation unloads the very Comin process running it.
      # The daemon exits after a successful switch and launchd starts the new
      # binary using the updated profile and config symlink.
      environment.etc."comin/config.yaml".source = cominConfig.cominConfigYaml;

      # The upstream Comin module reads this option for its executable PATH.
      # With `nix.enable = false`, Determinate still owns the daemon.
      nix.package = lib.mkDefault pkgs.nix;
      launchd.daemons.comin = lib.mkIf config.services.comin.allowForcePush {
        serviceConfig.EnvironmentVariables.COMIN_ALLOW_FORCE_PUSH = "true";
      };
    };
}
