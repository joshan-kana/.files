let
  roamingModule =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      inherit (lib) mkOption types;
      cfg = config.services.technitium-dns-server.roamingDns;
      settingsFile = (pkgs.formats.json { }).generate "technitium-roaming-dns.json" {
        inherit (cfg)
          lanSubnet
          remoteDnsSource
          pollSeconds
          timeoutMs
          answerTtl
          devices
          ;
      };
    in
    {
      options.services.technitium-dns-server.roamingDns = {
        enable = lib.mkEnableOption "Technitium roaming DNS postprocessor";
        lanSubnet = mkOption {
          type = types.str;
          description = "LAN CIDR used for direct roaming-host answers.";
        };
        remoteDnsSource = mkOption {
          type = types.str;
          description = "DNS client source address for remote 4via6 queries.";
        };
        pollSeconds = mkOption {
          type = types.ints.between 5 300;
          default = 10;
          description = "Seconds between endpoint health checks.";
        };
        timeoutMs = mkOption {
          type = types.ints.between 100 5000;
          default = 1500;
          description = "DNS lookup and connection timeout in milliseconds.";
        };
        answerTtl = mkOption {
          type = types.ints.between 5 60;
          default = 10;
          description = "TTL in seconds for rewritten DNS answers.";
        };
        devices = mkOption {
          type = types.listOf (
            types.submodule {
              options = {
                name = mkOption {
                  type = types.str;
                  description = "DHCP-managed DNS hostname.";
                };
                fallbackHost = mkOption {
                  type = types.str;
                  description = "DNS hostname used when the LAN endpoint is unreachable.";
                };
                port = mkOption {
                  type = types.ints.between 1 65535;
                  default = 22;
                  description = "TCP port used to check LAN reachability.";
                };
              };
            }
          );
          default = [ ];
          description = "Roaming hostnames and their alternate-network identities.";
        };
      };

      config = lib.mkIf (config.services.technitium-dns-server.enable && cfg.enable) {
        systemd.services.technitium-dns-server = {
          preStart = lib.mkAfter ''
            ${pkgs.coreutils}/bin/install -Dm644 ${pkgs.technitium-roaming-dns}/RoamingDns.dll \
              "$STATE_DIRECTORY/apps/RoamingDns/RoamingDns.dll"
            ${pkgs.coreutils}/bin/install -Dm644 ${pkgs.technitium-roaming-dns}/RoamingDns.deps.json \
              "$STATE_DIRECTORY/apps/RoamingDns/RoamingDns.deps.json"
            ${pkgs.coreutils}/bin/install -Dm644 ${settingsFile} \
              "$STATE_DIRECTORY/apps/RoamingDns/dnsApp.config"
          '';
          postStop = lib.mkAfter ''
            ${pkgs.coreutils}/bin/rm -f \
              "$STATE_DIRECTORY/apps/RoamingDns/RoamingDns.dll" \
              "$STATE_DIRECTORY/apps/RoamingDns/RoamingDns.deps.json" \
              "$STATE_DIRECTORY/apps/RoamingDns/dnsApp.config"
            ${pkgs.coreutils}/bin/rmdir "$STATE_DIRECTORY/apps/RoamingDns" 2>/dev/null || true
          '';
        };
      };
    };
  package =
    {
      stdenvNoCC,
      dotnetCorePackages,
      technitium-dns-server,
    }:

    stdenvNoCC.mkDerivation {
      pname = "technitium-roaming-dns";
      inherit (technitium-dns-server) version;
      src = ./.;
      nativeBuildInputs = [ dotnetCorePackages.sdk_10_0 ];
      dontConfigure = true;
      dontStrip = true;
      buildPhase = ''
        export HOME="$TMPDIR"
        export DOTNET_CLI_HOME="$TMPDIR"
        dotnet build RoamingDns.csproj -c Release \
          -p:TechnitiumLibDir=${technitium-dns-server}/lib/technitium-dns-server \
          -p:NuGetAudit=false -p:RestoreIgnoreFailedSources=true \
          -p:AnalysisMode=Recommended -p:TreatWarningsAsErrors=true
      '';
      installPhase = ''
        mkdir -p "$out"
        cp bin/Release/net10.0/RoamingDns.{dll,deps.json} "$out/"
      '';
    };
in
{ lib, system, ... }: {
  imports = lib.optionals (lib.systems.elaborate system).isLinux [ roamingModule ];

  nixpkgs.overlays = [
    (
      final: prev:
      prev.lib.optionalAttrs prev.stdenv.hostPlatform.isLinux {
        technitium-roaming-dns = final.callPackage package { };
      }
    )
  ];
}
