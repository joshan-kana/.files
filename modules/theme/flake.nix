{
  description = "Theme-selectable NixOS configurations";

  outputs =
    { self }:
    let
      # Re-open the repository root from the same immutable source. Using the
      # source hash keeps this pure without a second flake input or lock file.
      dotfiles = builtins.getFlake "path:${toString ../..}?narHash=${self.narHash}";
    in
    {
      nixosConfigurations = dotfiles.lib.themedNixosConfigurations;
    };
}
