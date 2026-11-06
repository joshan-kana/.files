_: {
  nixpkgs.overlays = [
    (
      _final: prev:
      prev.lib.optionalAttrs prev.stdenv.hostPlatform.isLinux {
        brave = prev.brave.overrideAttrs (old: {
          postInstall = (old.postInstall or "") + ''
            cat > "$out/opt/brave.com/brave/initial_preferences" <<'EOF'
            ${builtins.toJSON { extensions.theme.system_theme = 2; }}
            EOF
          '';
        });
      }
    )
  ];
}
