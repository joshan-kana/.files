{
  config,
  lib,
  pkgs,
  system,
  ...
}:

let
  inherit (lib.systems.elaborate system) isDarwin isLinux;
  upstream = builtins.getFlake "github:nlewo/comin/51e20d80b237b405009ddeb8c19a648eb95737e0";
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

  config = {
    services.comin = {
      grpc.unix_socket_group = if isDarwin then "staff" else "users";
      buildAttemptsLimit = 3;
    };

    nixpkgs.overlays = [
      (final: _prev: {
        comin = upstream.packages.${final.stdenv.hostPlatform.system}.comin.overrideAttrs (old: {
          version = "${old.version}-git.20261112-patched";
          __intentionallyOverridingVersion = true;
          ldflags = [ "-X github.com/nlewo/comin/cmd.version=${old.version}-git.20261112-patched" ];

          patches = (old.patches or [ ]) ++ [
            ../../patches/comin/allow-force-push.patch
            ../../patches/comin/watch-controls.patch
          ];
          passthru = (old.passthru or { }) // {
            autoUpdate = false;
          };
        });
      })
    ];
  }
  // lib.optionalAttrs isLinux {
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
    launchd.daemons.comin = lib.mkMerge [
      {
        command = lib.mkForce "/nix/var/nix/profiles/system-profiles/comin/sw/bin/comin run --config /etc/comin/config.yaml";
        serviceConfig.EnvironmentVariables.PATH = lib.mkForce "/run/current-system/sw/bin:/nix/var/nix/profiles/default/bin:/usr/bin:/bin";
      }
      (lib.mkIf config.services.comin.allowForcePush {
        serviceConfig.EnvironmentVariables.COMIN_ALLOW_FORCE_PUSH = "true";
      })
    ];
  };
}
