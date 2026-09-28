# Sources of truth

Executable configuration is the source of truth for current implementation facts.

- Nix option descriptions define configurable project interfaces.
- Evaluated configuration supplies host and semantic-scope reference state.
- Generated output is a build artifact rather than a committed copy of configuration facts.

Operational procedures belong in runbooks; current implementation facts remain sourced from executable configuration.
