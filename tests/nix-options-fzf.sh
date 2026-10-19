#!/usr/bin/env bash
set -euo pipefail

repo="$(git rev-parse --show-toplevel)"
nf="$repo/scripts/nix-options-fzf"
host="${1:-nixos-orbstack}"
hm_scope="home-manager:joshan"
test_cache="$(mktemp -d "${TMPDIR:-/tmp}/nix-options-fzf-test.XXXXXX")"
trap 'rm -rf -- "$test_cache"' EXIT

export XDG_CACHE_HOME="$test_cache"
export NIX_OPTIONS_FZF_DEFAULT_HOST_FILE="$test_cache/default-host"

run_nf() {
  "$nf" "$@"
}

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

assert_contains() {
  local output="$1"
  local expected="$2"
  local context="$3"

  grep -Fq -- "$expected" <<< "$output" || fail "$context (missing: $expected)"
}

assert_not_contains() {
  local output="$1"
  local unexpected="$2"
  local context="$3"

  if grep -Fq -- "$unexpected" <<< "$output"; then
    fail "$context (unexpected: $unexpected)"
  fi
}

assert_eq() {
  local actual="$1"
  local expected="$2"
  local context="$3"

  [ "$actual" = "$expected" ] || fail "$context (expected: $expected, actual: $actual)"
}

repo_cache_key="$(printf '%s\0' "$repo" | sha256sum | awk '{print substr($1, 1, 16)}')"
cache_root="$test_cache/dotfiles-options/$repo_cache_key"
mkdir -p "$cache_root/values-v2"
printf '%s\n' '[{"scope":"stale","name":"programs.gh.enable"}]' > "$cache_root/option-scopes-v2-$host.json"
printf '%s\n' stale > "$cache_root/values-v2/sentinel"

cold_list="$test_cache/cold-list"
cold_docs_stderr="$test_cache/cold-docs.stderr"
run_nf "$host" --refresh --list > "$cold_list" 2> "$cold_docs_stderr"
cache="$(run_nf "$host" --cache-path)"

assert_eq "$cache" "$cache_root/option-scopes-v3-$host.json" "current docs cache version"
assert_contains "$(<"$cold_docs_stderr")" "Building scoped option docs cache" "cold docs cache build"
[ -f "$cache_root/option-scopes-v2-$host.json" ] || fail "old docs cache was removed"
[ -f "$cache_root/values-v2/sentinel" ] || fail "old value cache was removed"
assert_eq "$(run_nf --default-host)" "$host" "remembered exact host"

jq -e --arg hm "$hm_scope" '
  any(.scope == $hm and .name == "programs.gh.enable")
  and any(.scope == $hm and .name == "stylix.enable")
  and any(.scope == "nixos" and .name == "services.openssh.enable")
  and any(.scope == "nixos" and .name == "dotfiles.profile.name")
  and any(.scope == "nixos" and .name == "home-manager.users")
  and any(.scope == $hm and .name == "home.services")
  and ([.[] | select(.name == "programs.zsh.enable") | .scope] | unique | length == 2)
  and any(.scope == $hm and .name == "programs.gh.enable"
    and any(.declarations[]; startswith("home-manager/")))
  and any(.scope == $hm and .name == "stylix.enable"
    and any(.declarations[]; startswith("stylix/")))
  and (any(.scope == $hm and .name == "programs.plasma.enable") | not)
  and (any(.scope == $hm and (.name | startswith("_module."))) | not)
  and (any(.scope == $hm and (.name | startswith("submoduleSupport."))) | not)
' "$cache" >/dev/null || fail "scoped docs, declarations, or host-specific imports are incomplete"

scopes="$(run_nf "$host" --scopes)"
assert_contains "$scopes" $'home-manager:joshan\tHome Manager: joshan' "Home Manager scope listing"
assert_contains "$scopes" $'nixos\tNixOS' "NixOS scope listing"

hm_list="$(run_nf "$host" programs --scope "$hm_scope" --list)"
assert_contains "$hm_list" "programs.gh.enable" "scope-filtered list"
assert_not_contains "$hm_list" $'programs.zsh.enable\tnixos' "scope-filtered collision list"

zsh_collision_count="$(run_nf "$host" programs.zsh --list | awk -F '\t' '$1 == "programs.zsh.enable" { count++ } END { print count + 0 }')"
assert_eq "$zsh_collision_count" 2 "same-name scoped records"

if ambiguity="$(run_nf "$host" --value programs.zsh.enable 2>&1)"; then
  fail "ambiguous option lookup unexpectedly succeeded"
fi
assert_contains "$ambiguity" "option is ambiguous across scopes" "ambiguous option diagnostic"
assert_contains "$ambiguity" "$hm_scope" "ambiguous option scopes"
assert_contains "$ambiguity" "nixos" "ambiguous option scopes"

if invalid_scope="$(run_nf "$host" --scope home-manager:nobody --value programs.gh.enable 2>&1)"; then
  fail "invalid scope unexpectedly succeeded"
fi
assert_contains "$invalid_scope" "invalid scope" "invalid scope diagnostic"

gh_cold_stderr="$test_cache/gh-cold.stderr"
gh_cold="$(NIX_OPTIONS_FZF_CACHE_DEBUG=1 run_nf "$host" --scope "$hm_scope" --value-full programs.gh.enable 2> "$gh_cold_stderr")"
assert_contains "$gh_cold" "current/effective value:" "Home Manager full value heading"
assert_contains "$gh_cold" $'current/effective value:\ntrue' "semantic Home Manager value"
assert_not_contains "$gh_cold" "<missing>" "defaulted Home Manager value"
assert_contains "$(<"$gh_cold_stderr")" "cache miss:" "cold full-value cache"

gh_warm_stderr="$test_cache/gh-warm.stderr"
gh_warm="$(NIX_OPTIONS_FZF_CACHE_DEBUG=1 run_nf "$host" --scope "$hm_scope" --value-full programs.gh.enable 2> "$gh_warm_stderr")"
assert_eq "$gh_warm" "$gh_cold" "warm full-value result"
assert_contains "$(<"$gh_warm_stderr")" "cache hit:" "warm full-value cache"

assert_contains "$(run_nf "$host" --scope "$hm_scope" --value programs.gh.enable)" $'current/effective value:\ntrue' "semantic Home Manager value"
assert_contains "$(run_nf "$host" --scope "$hm_scope" --value programs.zsh.enable)" $'current/effective value:\ntrue' "configured Home Manager zsh value"
assert_contains "$(run_nf "$host" --scope nixos --value programs.zsh.enable)" $'current/effective value:\ntrue' "configured NixOS zsh value"
assert_contains "$(run_nf "$host" --scope "$hm_scope" --value stylix.enable)" $'current/effective value:\ntrue' "configured Home Manager Stylix value"
assert_contains "$(run_nf "$host" --scope nixos --value stylix.enable)" $'current/effective value:\ntrue' "configured NixOS Stylix value"
assert_contains "$(run_nf "$host" --scope "$hm_scope" --value programs.bash.enable)" $'current/effective value:\nfalse' "defaulted Home Manager bash value"
assert_contains "$(run_nf "$host" --scope nixos --value programs.bash.enable)" $'current/effective value:\ntrue' "defaulted NixOS bash value"
assert_contains "$(run_nf "$host" --scope "$hm_scope" --value programs.git.enable)" $'current/effective value:\ntrue' "configured Home Manager git value"
assert_contains "$(run_nf "$host" --scope nixos --value programs.git.enable)" $'current/effective value:\nfalse' "defaulted NixOS git value"
assert_contains "$(run_nf "$host" --scope nixos --value services.openssh.enable)" $'current/effective value:\nfalse' "normal NixOS service value"
assert_contains "$(run_nf "$host" --scope nixos --value dotfiles.profile.name)" $'current/effective value:\nnixos-orbstack' "local custom option value"

short_packages="$({ export NIX_OPTIONS_FZF_VALUE_MAX_ITEMS=1; run_nf "$host" --scope nixos --value environment.systemPackages; })"
assert_contains "$short_packages" "<list:" "normal list value"
assert_contains "$short_packages" "... " "normal list truncation"
full_packages="$(run_nf "$host" --scope nixos --value-full environment.systemPackages)"
assert_contains "$full_packages" "<list:" "full list value"
assert_not_contains "$full_packages" "<missing>" "full list value"

gh_definitions="$(run_nf "$host" --scope "$hm_scope" --definitions programs.gh.enable)"
assert_contains "$gh_definitions" "Home Manager integration bridge" "semantic Home Manager origin"
assert_contains "$(run_nf "$host" --scope "$hm_scope" --definitions programs.zsh.enable)" "Home Manager integration bridge" "semantic Home Manager origin"
assert_contains "$(run_nf "$host" --scope "$hm_scope" --definitions stylix.enable)" "Home Manager integration bridge" "Home Manager integration origin"
assert_not_contains "$(run_nf "$host" --scope nixos --definitions services.openssh.enable)" "<unknown-file>" "NixOS service origin"
assert_not_contains "$(run_nf "$host" --scope nixos --definitions dotfiles.profile.name)" "<unknown-file>" "local custom option origin"

gh_item_origins="$(run_nf "$host" --scope "$hm_scope" --definition-items programs.gh.enable)"
assert_contains "$gh_item_origins" "true" "semantic scalar definition item"
assert_contains "$gh_item_origins" "Home Manager integration bridge" "semantic scalar item origin"
empty_item_origin="$(run_nf "$host" --scope "$hm_scope" --definition-item programs.bash.bashrcExtra "")"
assert_contains "$empty_item_origin" "[string]" "empty definition item lookup"
assert_not_contains "$empty_item_origin" "requires an item value" "empty definition item lookup"
invalid_item_origin="$(run_nf "$host" --scope "$hm_scope" --definition-item programs.git.settings does-not-exist)"
assert_contains "$invalid_item_origin" "<none>" "unknown definition item ID"
assert_not_contains "$invalid_item_origin" "local/modules/cli/" "unknown definition item ID"

docs_preview="$(NO_COLOR=1 run_nf "$host" --scope "$hm_scope" --preview programs.gh.enable)"
assert_contains "$docs_preview" "Home Manager: joshan ($hm_scope)" "scoped docs preview"
assert_contains "$docs_preview" "home-manager/modules/programs/gh.nix" "docs declaration and definition origin"
assert_contains "$docs_preview" $'declared default\n  false' "docs declared default"
assert_not_contains "$docs_preview" "<missing>" "docs preview"
assert_not_contains "$docs_preview" "<unknown-file>" "docs preview origin"
assert_not_contains "$docs_preview" "nixpkgs/lib/modules.nix" "docs preview origin"

hm_bash_doc="$(run_nf "$host" --scope "$hm_scope" --default programs.bash.enable)"
nixos_bash_doc="$(run_nf "$host" --scope nixos --default programs.bash.enable)"
assert_eq "$hm_bash_doc" "false" "Home Manager declared default metadata"
assert_eq "$nixos_bash_doc" "true" "NixOS declared default metadata"
assert_eq "$(run_nf "$host" --scope nixos --default security.acme.defaults)" "<none>" "NixOS submodule has no declared default"
assert_eq "$(run_nf "$host" --scope "$hm_scope" --default programs.borgmatic.backups)" "<none>" "Home Manager submodule has no declared default"

preview_helper="$cache_root/preview-option"
full_preview="$({
  export DOTFILES_OPTIONS_CACHE="$cache"
  export DOTFILES_OPTIONS_REPO="$repo"
  export DOTFILES_OPTIONS_SCOPE_FILTER="$hm_scope"
  export NIX_OPTIONS_FZF_PREVIEW_DELAY_MS=1
  export NO_COLOR=1
  "$preview_helper" full "$host" "$hm_scope" programs.gh.enable
})"
assert_contains "$full_preview" "preview debounce: 1ms" "preview debounce setting"
assert_contains "$full_preview" "full effective value" "full preview mode"
assert_contains "$full_preview" $'current/effective value:\ntrue' "live full preview value"
assert_not_contains "$full_preview" "<missing>" "live full preview value"

nixos_zsh_cache="$({ NIX_OPTIONS_FZF_CACHE_DEBUG=1 run_nf "$host" --scope nixos --value programs.zsh.enable >/dev/null; } 2>&1 | sed -n 's/^cache hit: //p')"
hm_zsh_cache="$({ NIX_OPTIONS_FZF_CACHE_DEBUG=1 run_nf "$host" --scope "$hm_scope" --value programs.zsh.enable >/dev/null; } 2>&1 | sed -n 's/^cache hit: //p')"
[ -n "$nixos_zsh_cache" ] && [ -n "$hm_zsh_cache" ] && [ "$nixos_zsh_cache" != "$hm_zsh_cache" ] \
  || fail "multi-scope value cache keys collided"

fzf() {
  local arg
  local call_count
  local selected

  : > "$NF_FZF_ARGV_FILE"
  for arg in "$@"; do
    printf '%s\n' "$arg" >> "$NF_FZF_ARGV_FILE"
  done

  call_count="$(<"$NF_FZF_STATE_FILE")"
  call_count=$((call_count + 1))
  printf '%s\n' "$call_count" > "$NF_FZF_STATE_FILE"
  cat > "$NF_FZF_INPUT_FILE.$call_count"

  case "$FZF_STUB_MODE" in
    ctrlp-hm-zsh)
      selected="$(awk -F '\t' -v scope="$hm_scope" '$1 == "programs.zsh.enable" && $3 == scope { print; exit }' "$NF_FZF_INPUT_FILE.$call_count")"
      [ -n "$selected" ] || return 1
      printf 'ctrl-p\n%s\n' "$selected"
      ;;
    ctrlp-unique)
      selected="$(awk -F '\t' -v scope="$hm_scope" '$1 == "programs.gh.enable" && $3 == scope { print; exit }' "$NF_FZF_INPUT_FILE.$call_count")"
      [ -n "$selected" ] || return 1
      printf 'ctrl-p\n%s\n' "$selected"
      ;;
    grouped-zoom)
      case "$call_count" in
        1)
          selected="$(awk -F '\t' '$1 == "programs/" { print; exit }' "$NF_FZF_INPUT_FILE.$call_count")"
          printf '%s\n' "$selected"
          ;;
        2)
          selected="$(awk -F '\t' '$1 == "programs.zsh/" { print; exit }' "$NF_FZF_INPUT_FILE.$call_count")"
          printf '%s\n' "$selected"
          ;;
        *)
          selected="$(awk -F '\t' -v scope="$hm_scope" '$1 == "programs.zsh.enable" && $3 == scope { print; exit }' "$NF_FZF_INPUT_FILE.$call_count")"
          printf 'ctrl-p\n%s\n' "$selected"
          ;;
      esac
      ;;
    prefix-back)
      selected="$(awk -F '\t' -v scope="$hm_scope" '$1 == "programs.zsh.enable" && $3 == scope { print; exit }' "$NF_FZF_INPUT_FILE.$call_count")"
      if [ "$call_count" -eq 1 ]; then
        printf 'ctrl-b\n%s\n' "$selected"
      else
        printf 'ctrl-p\n%s\n' "$selected"
      fi
      ;;
    toggle-mode)
      if [ "$call_count" -eq 1 ]; then
        selected="$(sed -n '1p' "$NF_FZF_INPUT_FILE.$call_count")"
        printf 'ctrl-o\n%s\n' "$selected"
      else
        return 1
      fi
      ;;
    value-search)
      sed -n '1p' "$NF_FZF_INPUT_FILE.$call_count"
      ;;
    *)
      return 1
      ;;
  esac
}
export -f fzf
export hm_scope

export NF_FZF_ARGV_FILE="$test_cache/fzf.argv"
export NF_FZF_INPUT_FILE="$test_cache/fzf.input"
export NF_FZF_STATE_FILE="$test_cache/fzf.state"

printf '0\n' > "$NF_FZF_STATE_FILE"
export FZF_STUB_MODE=ctrlp-hm-zsh
ctrlp_output="$(run_nf "$host" programs.zsh)"
assert_eq "$ctrlp_output" $'programs.zsh.enable\thome-manager:joshan' "Ctrl-P scoped collision identity"
assert_contains "$(<"$NF_FZF_ARGV_FILE")" "preview-option' full '$host' {3} {1}" "default full preview scoped identity"
assert_contains "$(<"$NF_FZF_ARGV_FILE")" "preview-option' value '$host' {3} {1}" "Ctrl-V scoped backing command"
assert_contains "$(<"$NF_FZF_ARGV_FILE")" "preview-option' full '$host' {3} {1}" "Ctrl-F scoped backing command"
assert_contains "$(<"$NF_FZF_ARGV_FILE")" "--scope {3} --value-search {1}" "Ctrl-S scoped backing command"
assert_contains "$(<"$NF_FZF_ARGV_FILE")" "--scope {3} --definition-items {1}" "Ctrl-I scoped backing command"
assert_contains "$(<"$NF_FZF_ARGV_FILE")" "preview-option' docs '$host' {3} {1}" "Ctrl-R scoped backing command"
assert_contains "$(<"$NF_FZF_INPUT_FILE.1")" $'programs.zsh.enable\t[Home Manager: joshan]\thome-manager:joshan' "interactive backing scope identity"

printf '0\n' > "$NF_FZF_STATE_FILE"
export FZF_STUB_MODE=ctrlp-unique
assert_eq "$(run_nf "$host" programs.gh)" "programs.gh.enable" "Ctrl-P unique natural option output"

printf '0\n' > "$NF_FZF_STATE_FILE"
export FZF_STUB_MODE=grouped-zoom
grouped_output="$(NIX_OPTIONS_FZF_LIST_MODE=grouped run_nf "$host")"
assert_eq "$grouped_output" $'programs.zsh.enable\thome-manager:joshan' "grouped Enter zoom and Ctrl-P identity"
assert_eq "$(<"$NF_FZF_STATE_FILE")" 3 "grouped navigation depth"
assert_contains "$(<"$NF_FZF_INPUT_FILE.1")" $'programs/\t\t-' "root grouped browsing"
assert_contains "$(<"$NF_FZF_INPUT_FILE.2")" $'programs.zsh/\t\t-' "nested grouped browsing"

printf '0\n' > "$NF_FZF_STATE_FILE"
export FZF_STUB_MODE=prefix-back
prefix_back_output="$(run_nf "$host" programs.zsh)"
assert_eq "$prefix_back_output" $'programs.zsh.enable\thome-manager:joshan' "prefix Ctrl-B navigation identity"
assert_eq "$(<"$NF_FZF_STATE_FILE")" 2 "prefix Ctrl-B redraw"

printf '0\n' > "$NF_FZF_STATE_FILE"
export FZF_STUB_MODE=toggle-mode
NIX_OPTIONS_FZF_LIST_MODE=flat run_nf "$host" programs >/dev/null
assert_eq "$(<"$NF_FZF_STATE_FILE")" 2 "Ctrl-O redraw"
assert_contains "$(<"$NF_FZF_INPUT_FILE.2")" $'programs.zsh/\t\t-' "Ctrl-O grouped mode"

printf '0\n' > "$NF_FZF_STATE_FILE"
export FZF_STUB_MODE=value-search
run_nf "$host" --scope "$hm_scope" --value-search programs.btop.settings >/dev/null
assert_contains "$(<"$NF_FZF_ARGV_FILE")" "--definition-item 'programs.btop.settings' {1}" "value-search item-origin preview"
assert_contains "$(<"$NF_FZF_INPUT_FILE.1")" "update_ms = 100" "value-search evaluated items"

printf '0\n' > "$NF_FZF_STATE_FILE"
run_nf "$host" --scope "$hm_scope" --value-search programs.zsh.initContent >/dev/null
multiline_record="$(<"$NF_FZF_INPUT_FILE.1")"
assert_contains "$multiline_record" '\n' "multiline value-search transport"
multiline_id="${multiline_record%%$'\t'*}"
multiline_origin="$(run_nf "$host" --scope "$hm_scope" --definition-item programs.zsh.initContent "$multiline_id")"
assert_contains "$multiline_origin" "Home Manager integration bridge" "multiline definition item lookup"
assert_not_contains "$multiline_origin" "$multiline_id" "multiline definition item display"

warm_docs_stderr="$test_cache/warm-docs.stderr"
run_nf "$host" --list >/dev/null 2> "$warm_docs_stderr"
assert_not_contains "$(<"$warm_docs_stderr")" "Building scoped option docs cache" "warm docs cache"
refresh_docs_stderr="$test_cache/refresh-docs.stderr"
run_nf "$host" --refresh --list >/dev/null 2> "$refresh_docs_stderr"
assert_contains "$(<"$refresh_docs_stderr")" "Building scoped option docs cache" "single-host refresh"

run_nf --clear-value-cache >/dev/null
[ -d "$cache_root/values-v3" ] || fail "current value cache directory was not recreated"
if find "$cache_root/values-v3" -type f -print -quit | grep -q .; then
  fail "current value cache was not cleared"
fi
[ -f "$cache_root/values-v2/sentinel" ] || fail "clearing current values removed old version"
post_clear_stderr="$test_cache/post-clear.stderr"
NIX_OPTIONS_FZF_CACHE_DEBUG=1 run_nf "$host" --scope "$hm_scope" --value-full programs.gh.enable >/dev/null 2> "$post_clear_stderr"
assert_contains "$(<"$post_clear_stderr")" "cache miss:" "cold value after clear"

hosts_output="$(run_nf --hosts)"
assert_contains "$hosts_output" $'nixos\taliases:' "host table exact name"
assert_contains "$hosts_output" "nixos-orbstack" "host table"
assert_contains "$hosts_output" $'mac\taliases: mac, m' "Darwin host discovery"

mac_scopes="$(run_nf mac --scopes)"
assert_contains "$mac_scopes" $'darwin\tDarwin' "Darwin system scope"
assert_contains "$mac_scopes" $'home-manager:joshan\tHome Manager: joshan' "Darwin Home Manager scope"
assert_contains "$(run_nf mac --scope darwin --value system.defaults.dock.autohide)" $'current/effective value:\ntrue' "Darwin configured system option"
assert_contains "$(run_nf mac --scope "$hm_scope" --value programs.zsh.enable)" $'current/effective value:\ntrue' "Darwin Home Manager value"


run_nf n --scopes >/dev/null
assert_eq "$(run_nf --default-host)" "nixos" "remembered alias resolution"
run_nf nixos --scopes >/dev/null
nixos_cache="$(run_nf nixos --cache-path)"
jq -e --arg hm "$hm_scope" 'any(.scope == $hm and .name == "programs.plasma.enable")' "$nixos_cache" >/dev/null \
  || fail "host-imported third-party Plasma options are missing"

run_nf o --scopes >/dev/null
assert_eq "$(run_nf --default-host)" "$host" "remembered host switch"
assert_contains "$(run_nf --scopes)" "$hm_scope" "bare command remembered host"

run_nf --clear-default-host >/dev/null
assert_eq "$(run_nf --default-host)" "<unset>" "clear remembered host"
fallback_scopes="$({ export NIX_OPTIONS_FZF_DEFAULT_HOST=o; run_nf --scopes; })"
assert_contains "$fallback_scopes" "$hm_scope" "environment host alias fallback"
run_nf o --scopes >/dev/null

server_stylix_origin="$(run_nf s --scope "$hm_scope" --definitions stylix.enable)"
assert_contains "$server_stylix_origin" "home-manager/nixos/common.nix [Home Manager integration bridge]" "server Home Manager integration origin"
run_nf o --scopes >/dev/null

refresh_all_stderr="$test_cache/refresh-all.stderr"
run_nf --refresh-all >/dev/null 2> "$refresh_all_stderr"
assert_eq "$(grep -c '^Building scoped option docs cache' "$refresh_all_stderr")" 5 "all-host refresh"
for refreshed_host in mac nixos nixos-arm-parallels nixos-orbstack nixos-server; do
  [ -s "$cache_root/option-scopes-v3-$refreshed_host.json" ] || fail "missing refreshed cache for $refreshed_host"
done

echo "PASS: complete scoped NixOS and Home Manager option browsing ($host)"
