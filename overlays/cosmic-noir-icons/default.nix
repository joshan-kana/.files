_: {
  nixpkgs.overlays = [
    (final: _prev: {
      cosmic-noir-icons = final.callPackage (
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

          passthru.autoUpdate = true;
          propagatedBuildInputs = [ hicolor-icon-theme ];
          nativeBuildInputs = [ python3 ];
          dontUnpack = true;
          dontBuild = true;

          installPhase = ''
            runHook preInstall
            mkdir -p "$out/share/icons/Cosmic-Noir-Orange"
            # Upstream ships case-only icon aliases. Preserve them on case-sensitive
            # filesystems, but avoid collisions on case-insensitive ones.
            python3 -c ${lib.escapeShellArg ''
              import os
              import posixpath
              import sys
              import tarfile

              archive_path, destination = sys.argv[1:]
              probe = os.path.join(destination, ".case-sensitive-probe")
              with open(probe, "w"):
                  pass
              try:
                  case_insensitive = os.path.exists(
                      os.path.join(destination, ".CASE-SENSITIVE-PROBE")
                  )
              finally:
                  os.unlink(probe)

              def priority(member):
                  if member.isfile() or member.isdir():
                      return 3
                  if member.issym():
                      target = posixpath.normpath(
                          posixpath.join(posixpath.dirname(member.name), member.linkname)
                      )
                      return 0 if target.casefold() == member.name.casefold() else 2
                  return 1

              with tarfile.open(archive_path, "r:xz") as archive:
                  members = archive.getmembers()
                  if case_insensitive:
                      selected = {}
                      for member in members:
                          key = member.name.casefold()
                          previous = selected.get(key)
                          if previous is None or priority(member) > priority(previous):
                              selected[key] = member
                      members = [
                          member for member in members
                          if priority(member) > 0 and selected[member.name.casefold()] is member
                      ]
                  archive.extractall(destination, members=members, filter="tar")
            ''} "$src" "$out/share/icons"
            runHook postInstall
          '';

          meta = {
            description = "Cosmic Noir icons with orange folders";
            homepage = "https://github.com/atraxsrc/cosmic-icon-themes";
            license = lib.licenses.gpl3Only;
            platforms = lib.platforms.all;
          };
        }
      ) { };
    })
  ];
}
