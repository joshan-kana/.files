{
  inputs,
  lib,
  stdenvNoCC,
  hicolor-icon-theme,
}:
stdenvNoCC.mkDerivation {
  name = "cosmic-noir-icons";

  src = inputs.cosmic-noir-icons;

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
