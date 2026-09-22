# Documentation model

`.files` treats executable configuration as the source of truth for current implementation facts.

- Nix option descriptions document configurable project interfaces.
- Evaluated configuration supplies host and semantic-scope reference state.
- Generated output is a build artifact rather than a second committed copy of configuration facts.

Later documentation layers can add authored operational guidance around this generated reference without changing those source-of-truth rules.
