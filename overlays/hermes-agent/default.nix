{ inputs, ... }: {
  nixpkgs.overlays = [
    (
      final: _prev:
      let
        system = final.stdenv.hostPlatform.system;
        llmAgentsPkgs = inputs.llm-agents.inputs.nixpkgs.legacyPackages.${system};
        upstream = inputs.llm-agents.packages.${system}.hermes-agent;
        python = llmAgentsPkgs.python3.withPackages (_: upstream.dependencies);
        hermesVenv = final.writeShellScriptBin "python3" ''
          export PYTHONPATH=${upstream}/${llmAgentsPkgs.python3.sitePackages}''${PYTHONPATH:+:$PYTHONPATH}
          exec ${python}/bin/python3 "$@"
        '';
      in
      {
        hermes-agent = upstream.overrideAttrs (old: {
          passthru = (old.passthru or { }) // {
            inherit hermesVenv;
          };
        });
      }
    )
  ];
}
