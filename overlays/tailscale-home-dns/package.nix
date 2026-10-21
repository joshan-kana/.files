{
  lib,
  stdenv,
  swift,
}:

stdenv.mkDerivation {
  pname = "tailscale-home-dns";
  version = "1.0.0";
  dontUnpack = true;
  nativeBuildInputs = [ swift ];
  buildPhase = ''
    swiftc -O ${./watch.swift} -o tailscale-home-dns
  '';
  installPhase = ''
    install -Dm755 tailscale-home-dns "$out/bin/tailscale-home-dns"
  '';
  meta = {
    mainProgram = "tailscale-home-dns";
    platforms = lib.platforms.darwin;
  };
}
