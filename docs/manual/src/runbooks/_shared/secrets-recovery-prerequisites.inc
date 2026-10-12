To access an existing encrypted secrets repository, recover its externally held
bootstrap configuration and password first. Keep these files outside Git and the
Nix store. Restore the existing repository rather than initializing another
one; only initialize a repository on first-ever provisioning.
