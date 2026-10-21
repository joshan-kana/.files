# Nix modules

**Convention:** Write readable native Nix module definitions with minimal abstraction. Local variables, conditions, and overrides should have a semantic reason, not exist merely to shorten expressions.

## Options and defaults

- Prefer a native NixOS or Home Manager option over an equivalent custom `dotfiles.*` wrapper.
- Prefer native package defaults; keep an explicit `package = pkgs.foo;` only when it meaningfully changes the module's effective package.
- Re-evaluate before deleting such settings. Some upstream defaults contain overrides even when their names look equivalent to `pkgs.foo`.
- Keep shared semantic children enabled by default where they apply.
- Use `inherit` for genuinely reused semantic values. Avoid a `let` block that merely aliases a one-off expression.
- Name policy inputs and values needing derivation, rather than scattering duplicated configurable ports or paths.
- Explain non-obvious behavior and constraints in comments; don't restate the following assignment.

## Conditionals

Use `lib.optionalAttrs` for conditional attribute **presence**, `lib.optionals` for list entries, `lib.mkIf` for module-system conditional definitions, and ordinary `if` for scalar or genuinely alternative values.

```nix
lib.optionalAttrs isLinux {
  programs.someTool.enable = true;
}
```

Do not build elaborate attribute merges to avoid an appropriate `if`. Platform conditions should ensure unsupported native options never enter the corresponding evaluation.

## Overrides and precedence

Use `lib.mkDefault` and `lib.mkForce` deliberately according to their actual merge semantics. Prefer a host-local override to altering shared scope machinery for a host exception. Preserve the default module behavior unless there is a documented reason to change it.

## Formatting and verification

Follow repository `nixfmt` output, including multiline function declarations and `home` fragments. Run `nix fmt -- --ci` and `nix flake check`. When moving or simplifying declarations, compare effective configuration and system derivations before assuming behavior is unchanged.
