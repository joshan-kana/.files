_:

let
  rules = builtins.readDir ./files/complex_modifications;
in
{
  services.karabiner-elements.enable = true;

  home = { lib, ... }: {
    # Keep Karabiner's live configuration writable for its UI, while restoring
    # the declared version on activation without removing automatic backups.
    home.activation.karabinerConfig = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      target="$HOME/.config/karabiner/karabiner.json"
      mkdir -p "$HOME/.config/karabiner"
      if ! /usr/bin/cmp -s "${./files/karabiner.json}" "$target"; then
        temp=$(/usr/bin/mktemp "$HOME/.config/karabiner/.karabiner.json.XXXXXX")
        /bin/cp "${./files/karabiner.json}" "$temp"
        /bin/chmod 0600 "$temp"
        /bin/mv -f "$temp" "$target"
        /bin/launchctl kickstart -k \
          "gui/$(/usr/bin/id -u)/org.pqrs.service.agent.Karabiner-Console-User-Server" \
          >/dev/null 2>&1 || true
      fi
    '';

    home.file = lib.mapAttrs' (
      name: _:
      lib.nameValuePair ".config/karabiner/assets/complex_modifications/${name}" {
        source = ./files/complex_modifications + "/${name}";
        force = true;
      }
    ) rules;
  };
}
