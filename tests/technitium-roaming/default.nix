{
  runCommand,
  dotnetCorePackages,
  technitium-dns-server,
}:

runCommand "technitium-roaming-tests"
  {
    nativeBuildInputs = [ dotnetCorePackages.sdk_10_0 ];
  }
  ''
    mkdir -p overlays tests
    cp -r ${../../overlays/technitium-roaming} overlays/technitium-roaming
    cp -r ${./.} tests/technitium-roaming
    chmod -R u+w overlays tests

    export HOME="$TMPDIR"
    export DOTNET_CLI_HOME="$TMPDIR"
    dotnet run --project tests/technitium-roaming/Tests.csproj -c Release \
      -p:TechnitiumLibDir=${technitium-dns-server}/lib/technitium-dns-server \
      -p:NuGetAudit=false -p:RestoreIgnoreFailedSources=true
    touch "$out"
  ''
