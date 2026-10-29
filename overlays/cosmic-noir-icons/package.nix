{
  lib,
  stdenvNoCC,
  hicolor-icon-theme,
  fetchurl,
  python3,
}:
let
  version = "1.2.0";
in
stdenvNoCC.mkDerivation {
  pname = "cosmic-noir-icons";
  inherit version;
  src = fetchurl {
    url = "https://github.com/atraxsrc/cosmic-icon-themes/releases/download/v${version}/Cosmic-Noir-Orange.tar.xz";
    hash = "sha256-EhlbwO0gjW95ERNZKqd04v4T9KRTeYzGhcJP5fIX8Hc=";
  };
  passthru.updateScript = [
    "${python3}/bin/python3"
    "${../../scripts/update-binary-release.py}"
    "cosmic-noir-icons"
  ];

  propagatedBuildInputs = [ hicolor-icon-theme ];
  dontUnpack = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall
    mkdir -p "$out/share/icons/Cosmic-Noir-Orange"
    tar -xJf "$src" --strip-components=1 -C "$out/share/icons/Cosmic-Noir-Orange"
    runHook postInstall
  '';

  meta = {
    description = "Cosmic Noir icons with orange folders";
    homepage = "https://github.com/atraxsrc/cosmic-icon-themes";
    license = lib.licenses.gpl3Only;
    platforms = lib.platforms.all;
  };
}
