_: {
  nixpkgs.overlays = [
    (
      final: prev:
      prev.lib.optionalAttrs prev.stdenv.hostPlatform.isLinux {
        chatgpt-shell-mcp-python = final.callPackage ./package.nix {
          python = final.python3;
        };
      }
    )
  ];
}
