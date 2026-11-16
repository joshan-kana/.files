# Paperless-ngx 3.4.2 restricts torch to versions before 2.15, while
# the selected nixpkgs supplies 2.15. Remove when the packaged metadata
# accepts the available version and native runtime validation passes.
_final: prev: {
  paperless-ngx = prev.paperless-ngx.overrideAttrs (old: {
    pythonRelaxDeps = (old.pythonRelaxDeps or [ ]) ++ [ "torch" ];
    passthru = (old.passthru or { }) // {
      autoUpdate = false;
    };
  });
}
