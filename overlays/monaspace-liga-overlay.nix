{ config, pkgs, ... }:
{
  nixpkgs.overlays = [
    (final: prev:
      let
        python = prev.python3.withPackages (ps: [ ps.fonttools ]);
        patchScript = prev.writeText "monaspace-promote-all-gsub-to-liga.py" ''
          import os
          import sys

          from fontTools.ttLib import TTFont
          from fontTools.ttLib.tables import otTables

          FONT_EXTENSIONS = (".otf", ".ttf", ".otc", ".ttc")

          # Guard against tiny-letter substitutions: these features are meant for
          # typography modes (sub/superscripts, fractions, etc.), not coding ligatures.
          EXCLUDED_FEATURE_TAGS = {
              "subs",  # Subscript
              "sups",  # Superscript
              "sinf",  # Scientific inferiors
              "ordn",  # Ordinals
              "numr",  # Numerators
              "dnom",  # Denominators
              "frac",  # Fractions
          }

          # Only promote features that are useful for code and unlikely to change
          # glyph sizing. Monaspace ligature behavior commonly lives in `calt` and
          # stylistic sets (`ssXX`). We intentionally do NOT promote character
          # variants (`cvXX`) because those are opt-in letterform changes.
          PROMOTE_BASE_TAGS = {"liga", "calt", "dlig", "clig", "rlig"}


          def should_promote_tag(tag: str | None) -> bool:
              if not tag:
                  return False
              if tag in EXCLUDED_FEATURE_TAGS:
                  return False
              if tag in PROMOTE_BASE_TAGS:
                  return True
              if len(tag) == 4 and tag[:2] == "ss" and tag[2:].isdigit():
                  # Monaspace uses the early stylistic sets for code ligatures.
                  # Later sets can be more decorative/typographic.
                  n = int(tag[2:])
                  return 1 <= n <= 8
              return False


          def iter_font_files(fonts_root: str):
              for root, _, files in os.walk(fonts_root):
                  for name in files:
                      if name.endswith(FONT_EXTENSIONS):
                          yield os.path.join(root, name)


          def promote_all_features_to_liga(font_path: str) -> bool:
              def compute_lookup_sets(ttfont: TTFont):
                  gsub = ttfont["GSUB"].table
                  feature_list = getattr(gsub, "FeatureList", None)
                  if not feature_list or not getattr(feature_list, "FeatureRecord", None):
                      return None

                  feature_records = list(feature_list.FeatureRecord)

                  all_lookup_indices: set[int] = set()
                  liga_record = None

                  for fr in feature_records:
                      tag = getattr(fr, "FeatureTag", None)
                      if tag == "liga":
                          liga_record = fr

                      # Only promote a safe allowlist; still locate `liga` even if
                      # we don't promote anything else.
                      if not should_promote_tag(tag):
                          continue

                      feature = getattr(fr, "Feature", None)
                      if feature is None:
                          continue
                      for idx in (getattr(feature, "LookupListIndex", None) or []):
                          all_lookup_indices.add(int(idx))

                  existing_liga: set[int] = set()
                  if liga_record is not None:
                      existing_liga = set(
                          int(i)
                          for i in (getattr(liga_record.Feature, "LookupListIndex", None) or [])
                      )

                  return feature_records, liga_record, all_lookup_indices, existing_liga

              # Fast pass: lazy-read just enough to decide whether we need to write.
              font = TTFont(
                  font_path,
                  lazy=True,
                  recalcBBoxes=False,
                  recalcTimestamp=False,
              )
              try:
                  if "GSUB" not in font:
                      return False
                  computed = compute_lookup_sets(font)
                  if computed is None:
                      return False
                  _, liga_record, all_lookup_indices, existing_liga = computed
                  if liga_record is not None and existing_liga == all_lookup_indices:
                      return False
              finally:
                  try:
                      font.close()
                  except Exception:
                      pass

              # Write pass: must not be lazy when overwriting the source file.
              font = TTFont(
                  font_path,
                  lazy=False,
                  recalcBBoxes=False,
                  recalcTimestamp=False,
              )
              try:
                  if "GSUB" not in font:
                      return False

                  gsub = font["GSUB"].table
                  feature_list = getattr(gsub, "FeatureList", None)
                  if not feature_list or not getattr(feature_list, "FeatureRecord", None):
                      return False

                  computed = compute_lookup_sets(font)
                  if computed is None:
                      return False
                  feature_records, liga_record, all_lookup_indices, _ = computed

                  if liga_record is None:
                      liga_record = otTables.FeatureRecord()
                      liga_record.FeatureTag = "liga"
                      liga_record.Feature = otTables.Feature()
                      feature_records.append(liga_record)

                  merged = sorted(all_lookup_indices)
                  liga_record.Feature.LookupListIndex = merged
                  liga_record.Feature.LookupCount = len(merged)
                  feature_list.FeatureRecord = feature_records

                  # Avoid extra work; table order doesn't matter for our change.
                  tmp_path = font_path + ".tmp"
                  font.save(tmp_path, reorderTables=False)
                  os.replace(tmp_path, font_path)
                  return True
              finally:
                  try:
                      font.close()
                  except Exception:
                      pass


          def main() -> int:
              if len(sys.argv) != 2:
                  print("usage: monaspace-promote-all-gsub-to-liga.py <fonts-root>", file=sys.stderr)
                  return 2

              fonts_root = sys.argv[1]
              patched = 0

              for path in iter_font_files(fonts_root):
                  try:
                      patched += 1 if promote_all_features_to_liga(path) else 0
                  except Exception as e:
                      print(f"warn: failed to patch {path}: {e}", file=sys.stderr)

              if patched == 0:
                  print("warn: no fonts patched", file=sys.stderr)

              return 0


          if __name__ == "__main__":
              raise SystemExit(main())
        '';
      in
      {
        monaspace-liga = prev.stdenvNoCC.mkDerivation {
          pname = "monaspace-liga";
          version = prev.monaspace.version or "unknown";
          dontUnpack = true;
                    phases = [ "installPhase" ];
          nativeBuildInputs = [ python ];

          # Fonts-only output; skip the expensive generic fixup scans.
          dontFixup = true;
          dontPatchShebangs = true;

          installPhase = ''
            runHook preInstall

            mkdir -p "$out/share"

            # Copy with dereference so we get real font files (not symlinks).
            # reflink is a fast-path when supported.
            cp -aL --reflink=auto "${prev.monaspace}/share/fonts" "$out/share/"

            # Ensure files are writable for patching
            chmod -R u+w "$out/share/fonts" || true

            ${python}/bin/python ${patchScript} "$out/share/fonts"

            runHook postInstall
          '';

          meta = (prev.monaspace.meta or { }) // {
                        description = "Monaspace with code-oriented GSUB features promoted into 'liga' (calt/ssXX/cvXX; excludes sub/sup/fractions)";
          };
        };
      })
  ];
}
