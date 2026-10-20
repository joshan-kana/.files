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
      -p:NuGetAudit=false -p:RestoreIgnoreFailedSources=true
  '';
  installPhase = ''
    mkdir -p "$out"
    cp bin/Release/net10.0/RoamingDns.{dll,deps.json} "$out/"
  '';
}
