#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

# Defaults keep direct invocations predictable; the Nix-installed wrapper
# exports the evaluated server values.
OPEN_WEBUI_SERVER_IP="${OPEN_WEBUI_SERVER_IP:-192.168.1.3}"
OPEN_WEBUI_SECRETS_DIR="${OPEN_WEBUI_SECRETS_DIR:-/root/secrets}"
OPEN_WEBUI_ASSET_ROOT="${OPEN_WEBUI_ASSET_ROOT:-$script_dir}"
OPEN_WEBUI_PRIMARY_USER="${OPEN_WEBUI_PRIMARY_USER:-joshan}"
OPEN_WEBUI_PORT="${OPEN_WEBUI_PORT:-8081}"
OPEN_WEBUI_COMPUTER_PORT="${OPEN_WEBUI_COMPUTER_PORT:-8000}"
OPEN_WEBUI_COMPUTER_SETUP_TOKEN_FILE="${OPEN_WEBUI_COMPUTER_SETUP_TOKEN_FILE:-/run/open-webui-computer/setup-token}"
OPEN_WEBUI_GITHUB_MCP_PORT="${OPEN_WEBUI_GITHUB_MCP_PORT:-8082}"
OPEN_WEBUI_AGENT_MAIL_PORT="${OPEN_WEBUI_AGENT_MAIL_PORT:-8765}"
OPEN_WEBUI_GITHUB_SECRET="${OPEN_WEBUI_GITHUB_SECRET:-${OPEN_WEBUI_SECRETS_DIR}/open-webui-github.env}"
OPEN_WEBUI_HOST_ADMIN_KEY_SECRET="${OPEN_WEBUI_HOST_ADMIN_KEY_SECRET:-${OPEN_WEBUI_SECRETS_DIR}/open-webui-host-admin-id_ed25519}"

open_webui_base="http://${OPEN_WEBUI_SERVER_IP}:${OPEN_WEBUI_PORT}"
computer_base="http://${OPEN_WEBUI_SERVER_IP}:${OPEN_WEBUI_COMPUTER_PORT}"
open_webui_secret="${OPEN_WEBUI_SECRETS_DIR}/open-webui.env"
searx_secret="${OPEN_WEBUI_SECRETS_DIR}/searxng.env"
computer_secret="${OPEN_WEBUI_SECRETS_DIR}/open-webui-computer.env"
mac_secret="${OPEN_WEBUI_SECRETS_DIR}/open-webui-mac-computer.env"
github_secret="$OPEN_WEBUI_GITHUB_SECRET"
host_admin_key_secret="$OPEN_WEBUI_HOST_ADMIN_KEY_SECRET"
notification_id="dotfiles-unattended-work"

umask 0077
sync_tmp_dir="$(mktemp -d)"
trap 'rm -rf -- "$sync_tmp_dir"' EXIT

usage() {
  cat <<'EOF'
usage: open-webui-sync {init-secrets|sync|all}

  init-secrets  Create missing stable Open WebUI/SearXNG/Computer/host-key
                secrets. Existing values are never rotated.
  sync          Reconcile the intentionally managed application settings after
                Open WebUI and Computer are running. Unrelated settings remain.
  all           Run init-secrets, then sync.

Required GitHub access is read from /root/secrets/open-webui-github.env
and must define GH_TOKEN.

Optional server Computer model policy lives only in
/root/secrets/open-webui-computer.env:
  CPTR_MODEL_BASE_URL=...
  CPTR_MODEL_API_KEY=...
  CPTR_MODEL_ID=...
  CPTR_MODEL_PROVIDER=openai        # optional
  CPTR_MODEL_PREFIX=server-worker   # optional
  CPTR_GATEWAY_MODEL=...            # optional explicit gateway choice

Optional unattended notifications use:
  OPEN_WEBUI_NOTIFICATION_WEBHOOK_URL=...
in /root/secrets/open-webui.env.
EOF
}

require_root() {
  if [[ ${EUID:-$(id -u)} -ne 0 ]]; then
    echo "open-webui-sync must run as root (use sudo)." >&2
    exit 1
  fi
}

secret_hex() {
  od -An -N32 -tx1 /dev/urandom | tr -d ' \n'
}

private_file() {
  local value="$1" file
  file="$(mktemp "$sync_tmp_dir/private.XXXXXX")"
  printf '%s' "$value" >"$file"
  printf '%s' "$file"
}

curl_json() {
  local payload="$1"
  shift
  printf '%s' "$payload" | curl "$@" --data-binary @-
}

curl_bearer() {
  local token="$1" header status=0
  shift
  header="$(mktemp "$sync_tmp_dir/header.XXXXXX")"
  printf 'Authorization: Bearer %s\n' "$token" >"$header"
  curl -H "@$header" "$@" || status=$?
  rm -f "$header"
  return "$status"
}

curl_bearer_json() {
  local token="$1" payload="$2" header status=0
  shift 2
  header="$(mktemp "$sync_tmp_dir/header.XXXXXX")"
  printf 'Authorization: Bearer %s\n' "$token" >"$header"
  printf '%s' "$payload" | curl -H "@$header" "$@" --data-binary @- || status=$?
  rm -f "$header"
  return "$status"
}

get_value() {
  local file="$1" key="$2"
  [[ -f "$file" ]] || return 0
  sed -n "s/^${key}=//p" "$file" | tail -n 1
}

set_value() {
  local file="$1" key="$2" value="$3" tmp
  tmp="$(mktemp "$sync_tmp_dir/secret-env.XXXXXX")"
  [[ ! -f "$file" ]] || grep -v "^${key}=" "$file" >"$tmp" || true
  printf '%s=%s\n' "$key" "$value" >>"$tmp"
  install -m 0400 -o root -g root "$tmp" "$file"
  rm -f "$tmp"
}

ensure_value() {
  local file="$1" key="$2" value="$3"
  [[ -n "$(get_value "$file" "$key")" ]] || set_value "$file" "$key" "$value"
}

init_secrets() {
  require_root
  [[ -d "$OPEN_WEBUI_SECRETS_DIR" ]] || {
    echo "$OPEN_WEBUI_SECRETS_DIR is missing; activate the server configuration first." >&2
    return 1
  }

  touch "$open_webui_secret" "$searx_secret" "$computer_secret"
  chown root:root "$open_webui_secret" "$searx_secret" "$computer_secret"
  chmod 0600 "$open_webui_secret" "$searx_secret" "$computer_secret"

  ensure_value "$open_webui_secret" WEBUI_SECRET_KEY "$(secret_hex)"
  ensure_value "$open_webui_secret" WEBUI_ADMIN_EMAIL "${OPEN_WEBUI_ADMIN_EMAIL:-joshan@localhost}"
  ensure_value "$open_webui_secret" WEBUI_ADMIN_PASSWORD "$(secret_hex)"
  ensure_value "$searx_secret" SEARX_SECRET_KEY "$(secret_hex)"
  ensure_value "$computer_secret" CPTR_ADMIN_PASSWORD "$(secret_hex)"

  if [[ ! -e "$host_admin_key_secret" ]]; then
    ssh-keygen -q -t ed25519 -N '' -C open-webui-host-admin@nixos-server -f "$host_admin_key_secret"
    rm -f "$host_admin_key_secret.pub"
  fi

  chown root:root "$host_admin_key_secret"
  chmod 0400 "$open_webui_secret" "$searx_secret" "$computer_secret" "$host_admin_key_secret"
  echo "Initialized missing Open WebUI secrets without rotating existing values."
  [[ -s "$github_secret" ]] || \
    echo "NOTE: provision $github_secret with GH_TOKEN before running sync." >&2
}

wait_for() {
  local url="$1" name="$2"
  for _ in $(seq 1 60); do
    curl -fsS "$url" >/dev/null 2>&1 && return 0
    sleep 1
  done
  echo "$name did not become healthy at $url" >&2
  return 1
}

computer_login() {
  local cookies="$1" password="$2" password_file payload
  password_file="$(private_file "$password")"
  payload="$(jq -cn --arg u "$OPEN_WEBUI_PRIMARY_USER" --rawfile p "$password_file" '{username:$u,password:$p}')"
  curl_json "$payload" -fsS -c "$cookies" -H 'Content-Type: application/json' \
    "$computer_base/api/auth/login" >/dev/null
}

computer_setup() {
  local cookies="$1" password="$2" startup_token password_file token_file payload response status body
  computer_login "$cookies" "$password" 2>/dev/null && return 0

  startup_token="$(cat "$OPEN_WEBUI_COMPUTER_SETUP_TOKEN_FILE" 2>/dev/null || true)"
  if [[ -z "$startup_token" ]]; then
    echo "Computer cannot be logged in with its managed secret and its current first-run token is unavailable." >&2
    echo "Restore $computer_secret or restart Computer and retry setup deliberately." >&2
    return 1
  fi

  password_file="$(private_file "$password")"
  token_file="$(private_file "$startup_token")"
  payload="$(jq -cn --arg u "$OPEN_WEBUI_PRIMARY_USER" --rawfile p "$password_file" --rawfile t "$token_file" \
    '{username:$u,password:$p,token:$t,display_name:"Joshan"}')"
  response="$(curl_json "$payload" -sS -c "$cookies" -H 'Content-Type: application/json' \
    -w $'\n%{http_code}' "$computer_base/api/auth/setup")"
  status="${response##*$'\n'}"
  body="${response%$'\n'*}"

  case "$status" in
    200) return 0 ;;
    400)
      if jq -e '.error == "already set up"' <<<"$body" >/dev/null 2>&1; then
        echo "Computer is already initialized but CPTR_ADMIN_PASSWORD does not match the managed account." >&2
        echo "Restore $computer_secret or reset the Computer account deliberately." >&2
      else
        echo "Computer first-run setup was rejected with HTTP 400." >&2
      fi
      ;;
    403)
      echo "Computer rejected its current first-run token; restart Computer and retry." >&2
      ;;
    *) echo "Computer first-run setup failed with HTTP $status." >&2 ;;
  esac
  return 1
}

computer_workspace() {
  local cookies="$1" workspace="$2" name="$3" encoded
  encoded="$(jq -rn --arg value "$workspace" '$value|@uri')"
  curl -fsS -b "$cookies" -X PUT -H 'Content-Type: application/json' \
    -d "$(jq -cn --arg name "$name" '{name:$name}')" \
    "$computer_base/api/state/workspace?path=$encoded" >/dev/null
}

computer_gateway_key() {
  local cookies="$1" key
  key="$(get_value "$computer_secret" CPTR_GATEWAY_API_KEY)"
  if [[ -n "$key" ]] && curl_bearer "$key" -fsS "$computer_base/v1/models" >/dev/null 2>&1; then
    printf '%s' "$key"
    return
  fi

  key="$(curl_json '{"name":"open-webui-server"}' -fsS -b "$cookies" -H 'Content-Type: application/json' \
    "$computer_base/v1/keys" | jq -er '.key')"
  set_value "$computer_secret" CPTR_GATEWAY_API_KEY "$key"
  printf '%s' "$key"
}

sync_computer_model() {
  local cookies="$1" base key model provider prefix gateway existing id key_file payload
  base="$(get_value "$computer_secret" CPTR_MODEL_BASE_URL)"
  key="$(get_value "$computer_secret" CPTR_MODEL_API_KEY)"
  model="$(get_value "$computer_secret" CPTR_MODEL_ID)"
  provider="$(get_value "$computer_secret" CPTR_MODEL_PROVIDER)"
  prefix="$(get_value "$computer_secret" CPTR_MODEL_PREFIX)"
  gateway="$(get_value "$computer_secret" CPTR_GATEWAY_MODEL)"
  provider="${provider:-openai}"
  prefix="${prefix:-server-worker}"

  if [[ -n "$base$key$model" ]]; then
    if [[ -z "$base" || -z "$key" || -z "$model" ]]; then
      echo "Partial CPTR_MODEL_* configuration; skipping server Computer model connection." >&2
    else
      existing="$(curl -fsS -b "$cookies" "$computer_base/api/admin/connections")"
      id="$(printf '%s' "$existing" | jq -r --arg p "$prefix" '.connections[]? | select(.prefix_id==$p) | .id' | head -n1)"
      key_file="$(private_file "$key")"
      payload="$(jq -cn --arg provider "$provider" --arg prefix "$prefix" --arg base "$base" --rawfile key "$key_file" --arg model "$model" \
        '{name:"Server worker model",provider:$provider,api_type:"chat_completions",prefix_id:$prefix,base_url:$base,api_key:$key,enabled:true,models:[$model]}')"
      if [[ -n "$id" ]]; then
        curl_json "$payload" -fsS -b "$cookies" -X PUT -H 'Content-Type: application/json' \
          "$computer_base/api/admin/connections/$id" >/dev/null
      else
        curl_json "$payload" -fsS -b "$cookies" -H 'Content-Type: application/json' \
          "$computer_base/api/admin/connections" >/dev/null
      fi
    fi
  fi

  if [[ -n "$gateway" ]]; then
    curl_json "$(jq -cn --arg model "$gateway" '{config:{"gateway.model":$model}}')" \
      -fsS -b "$cookies" -X PUT -H 'Content-Type: application/json' \
      "$computer_base/api/admin/config" >/dev/null
  fi
}

computer_tool_server() {
  local cookies="$1" id="$2" url="$3" auth_type="$4" key="$5" name="$6" current key_file create update
  current="$(curl -fsS -b "$cookies" "$computer_base/api/admin/tools/servers")"
  key_file="$(private_file "$key")"
  create="$(jq -cn --arg id "$id" --arg url "$url" --arg auth "$auth_type" --rawfile key "$key_file" --arg name "$name" \
    '{id:$id,type:"mcp",url:$url,path:"",auth_type:$auth,key:(if $key=="" then null else $key end),name:$name,description:"Managed explicitly by joshan-kana/.files",enabled:true}')"
  update="$(jq -cn --arg url "$url" --arg auth "$auth_type" --rawfile key "$key_file" --arg name "$name" \
    '{type:"mcp",url:$url,path:"",auth_type:$auth,key:(if $key=="" then null else $key end),name:$name,description:"Managed explicitly by joshan-kana/.files",enabled:true}')"

  if jq -e --arg id "$id" 'any(.servers[]?; .id==$id)' <<<"$current" >/dev/null; then
    curl_json "$update" -fsS -b "$cookies" -X PUT -H 'Content-Type: application/json' \
      "$computer_base/api/admin/tools/servers/$id" >/dev/null
  else
    curl_json "$create" -fsS -b "$cookies" -H 'Content-Type: application/json' \
      "$computer_base/api/admin/tools/servers" >/dev/null
  fi
}

sync_computer_tools() {
  local cookies="$1" github_token
  github_token="$(get_value "$github_secret" GH_TOKEN)"
  : "${github_token:?$github_secret must define GH_TOKEN}"
  computer_tool_server "$cookies" github \
    "http://127.0.0.1:${OPEN_WEBUI_GITHUB_MCP_PORT}/mcp" \
    bearer "$github_token" "GitHub"

  computer_tool_server "$cookies" agent_mail \
    "http://127.0.0.1:${OPEN_WEBUI_AGENT_MAIL_PORT}/mcp/" \
    none "" "Agent Mail Rust"
}

sync_computer() {
  [[ -f "$computer_secret" ]] || {
    echo "$computer_secret is missing; run: sudo open-webui-sync init-secrets" >&2
    return 1
  }
  wait_for "$computer_base/api/health" "Open WebUI Computer"

  local cookies password
  cookies="$(mktemp "$sync_tmp_dir/computer-cookies.XXXXXX")"
  password="$(get_value "$computer_secret" CPTR_ADMIN_PASSWORD)"
  : "${password:?$computer_secret must define CPTR_ADMIN_PASSWORD}"
  computer_setup "$cookies" "$password"

  computer_workspace "$cookies" "/home/$OPEN_WEBUI_PRIMARY_USER/.files" ".files"
  computer_workspace "$cookies" "/home/$OPEN_WEBUI_PRIMARY_USER" "nixos-server"

  # Persist only intentional Computer application settings. Computer owns them
  # after this explicit sync; they are not re-applied by systemd on every boot.
  curl -fsS -b "$cookies" -X PUT -H 'Content-Type: application/json' \
    -d "$(jq -cn '{config:{"web.enabled":true,"web.search_provider":"searxng","web.searxng_base_url":"http://127.0.0.1:8888","browser.enabled":true,"browser.provider":"local","browser.auto_launch":true,"browser.tab_default_mode":"chrome","browser.tab_chrome_source":"managed"}}')" \
    "$computer_base/api/admin/config" >/dev/null

  computer_gateway_key "$cookies" >/dev/null
  sync_computer_model "$cookies"
  sync_computer_tools "$cookies"
  rm -f "$cookies"
}

openwebui_token() {
  local email password password_file payload
  email="$(get_value "$open_webui_secret" WEBUI_ADMIN_EMAIL)"
  password="$(get_value "$open_webui_secret" WEBUI_ADMIN_PASSWORD)"
  : "${email:?$open_webui_secret must define WEBUI_ADMIN_EMAIL}"
  : "${password:?$open_webui_secret must define WEBUI_ADMIN_PASSWORD}"
  password_file="$(private_file "$password")"
  payload="$(jq -cn --arg email "$email" --rawfile password "$password_file" '{email:$email,password:$password}')"
  curl_json "$payload" -fsS -H 'Content-Type: application/json' \
    "$open_webui_base/api/v1/auths/signin" | jq -er '.token'
}

computer_headers_json() {
  jq -cn '{
    "X-OpenWebUI-Chat-Id":"{{CHAT_ID}}",
    "X-OpenWebUI-Message-Id":"{{MESSAGE_ID}}",
    "X-OpenWebUI-User-Message-Id":"{{USER_MESSAGE_ID}}",
    "X-OpenWebUI-User-Message-Parent-Id":"{{USER_MESSAGE_PARENT_ID}}",
    "X-OpenWebUI-Task":"{{TASK}}"
  }'
}

sync_openai_connections() {
  local token="$1" server_key="$2" current entries preserved managed all headers
  local server_key_file mac_url mac_key mac_key_file managed_file preserved_file all_file payload
  headers="$(computer_headers_json)"
  server_key_file="$(private_file "$server_key")"
  managed="$(jq -cn --arg url "http://${OPEN_WEBUI_SERVER_IP}:${OPEN_WEBUI_COMPUTER_PORT}/v1" --rawfile key "$server_key_file" --argjson headers "$headers" \
    '[{url:$url,key:$key,config:{enable:true,prefix_id:"server",provider:"Open WebUI Computer (server)",headers:$headers}}]')"

  if [[ -s "$mac_secret" ]]; then
    mac_url="$(get_value "$mac_secret" CPTR_BASE_URL)"
    mac_key="$(get_value "$mac_secret" CPTR_GATEWAY_API_KEY)"
    if [[ -n "$mac_url" && -n "$mac_key" ]]; then
      mac_key_file="$(private_file "$mac_key")"
      managed_file="$(private_file "$managed")"
      managed="$(jq -cn --slurpfile cur "$managed_file" --arg url "$mac_url" --rawfile key "$mac_key_file" --argjson headers "$headers" \
        '$cur[0] + [{url:$url,key:$key,config:{enable:true,prefix_id:"mac",provider:"Open WebUI Computer (Mac)",headers:$headers}}]')"
    fi
  fi

  current="$(curl_bearer "$token" -fsS "$open_webui_base/openai/config")"
  entries="$(printf '%s' "$current" | jq -c '(.OPENAI_API_BASE_URLS//[]) as $u | (.OPENAI_API_KEYS//[]) as $k | (.OPENAI_API_CONFIGS//{}) as $c | [range(0;($u|length)) as $i | {url:$u[$i],key:($k[$i]//""),config:($c[($i|tostring)]//{})}]')"
  preserved="$(printf '%s' "$entries" | jq -c 'map(select(((.config.prefix_id//"")!="server") and ((.config.prefix_id//"")!="mac")))')"
  preserved_file="$(private_file "$preserved")"
  managed_file="$(private_file "$managed")"
  all="$(jq -cn --slurpfile keep "$preserved_file" --slurpfile managed "$managed_file" '$keep[0]+$managed[0]')"
  all_file="$(private_file "$all")"
  payload="$(jq -cn --slurpfile wrapped "$all_file" '$wrapped[0] as $e | {ENABLE_OPENAI_API:true,OPENAI_API_BASE_URLS:[$e[].url],OPENAI_API_KEYS:[$e[].key],OPENAI_API_CONFIGS:(reduce range(0;($e|length)) as $i ({}; .[($i|tostring)]=$e[$i].config))}')"

  curl_bearer_json "$token" "$payload" -fsS -H 'Content-Type: application/json' \
    "$open_webui_base/openai/config/update" >/dev/null
}

sync_tool_servers() {
  local token="$1" current preserved managed all github_token github_file managed_file preserved_file all_file payload
  current="$(curl_bearer "$token" -fsS "$open_webui_base/api/v1/configs/tool_servers" | jq -c '.TOOL_SERVER_CONNECTIONS//[]')"
  preserved="$(printf '%s' "$current" | jq -c '
    map(select(((.info // {}).id // "") as $id | (["github","native-sessions","agent-mail"] | index($id) | not)))
  ')"
  managed='[]'

  github_token="$(get_value "$github_secret" GH_TOKEN)"
  : "${github_token:?$github_secret must define GH_TOKEN}"
  github_file="$(private_file "$github_token")"
  managed="$(jq -cn --rawfile key "$github_file" --arg url "http://127.0.0.1:${OPEN_WEBUI_GITHUB_MCP_PORT}/mcp" \
    '[{url:$url,path:"",type:"mcp",auth_type:"bearer",headers:null,key:$key,config:{enable:true},info:{id:"github",name:"GitHub"}}]')"

  managed_file="$(private_file "$managed")"
  managed="$(jq -cn --slurpfile cur "$managed_file" --arg url "http://127.0.0.1:${OPEN_WEBUI_AGENT_MAIL_PORT}/mcp/" \
    '$cur[0] + [{url:$url,path:"",type:"mcp",auth_type:"none",headers:null,key:"",config:{enable:true},info:{id:"agent-mail",name:"Agent Mail Rust"}}]')"

  preserved_file="$(private_file "$preserved")"
  managed_file="$(private_file "$managed")"
  all="$(jq -cn --slurpfile keep "$preserved_file" --slurpfile managed "$managed_file" '$keep[0]+$managed[0]')"
  all_file="$(private_file "$all")"
  payload="$(jq -cn --slurpfile c "$all_file" '{TOOL_SERVER_CONNECTIONS:$c[0]}')"
  curl_bearer_json "$token" "$payload" -fsS -H 'Content-Type: application/json' \
    "$open_webui_base/api/v1/configs/tool_servers" >/dev/null
}

sync_folders() {
  local token="$1" folders name payload
  folders="$(curl_bearer "$token" -fsS "$open_webui_base/api/v1/folders/")"
  for name in 'General' '.files' 'Project Speed' 'Home Automation' 'Research' 'University'; do
    if ! printf '%s' "$folders" | jq -e --arg name "$name" 'any(.[]?; .name==$name)' >/dev/null; then
      payload="$(jq -cn --arg name "$name" '{name:$name}')"
      curl_bearer_json "$token" "$payload" -fsS -H 'Content-Type: application/json' \
        "$open_webui_base/api/v1/folders/" >/dev/null
      folders="$(curl_bearer "$token" -fsS "$open_webui_base/api/v1/folders/")"
    fi
  done
}

sync_prompts() {
  local token="$1" current row command id payload
  current="$(curl_bearer "$token" -fsS "$open_webui_base/api/v1/prompts/")"
  while IFS= read -r row; do
    command="$(jq -r '.command' <<<"$row")"
    id="$(jq -r --arg command "$command" '.[]? | select(.command==$command) | .id' <<<"$current" | head -n1)"
    payload="$(jq -c '{command,name,content,tags:(.tags//[]),meta:(.meta//{})}' <<<"$row")"
    if [[ -n "$id" ]]; then
      curl_bearer_json "$token" "$payload" -fsS -H 'Content-Type: application/json' \
        "$open_webui_base/api/v1/prompts/id/$id/update" >/dev/null
    else
      curl_bearer_json "$token" "$payload" -fsS -H 'Content-Type: application/json' \
        "$open_webui_base/api/v1/prompts/create" >/dev/null
    fi
  done < <(jq -c '.[]' "$OPEN_WEBUI_ASSET_ROOT/prompts.json")
}

sync_skills() {
  local token="$1" current row id payload
  current="$(curl_bearer "$token" -fsS "$open_webui_base/api/v1/skills/")"
  while IFS= read -r row; do
    id="$(jq -r '.id' <<<"$row")"
    payload="$(jq -c '{id,name,description,content,meta:(.meta//{}),is_active:(.is_active//true)}' <<<"$row")"
    if jq -e --arg id "$id" 'any(.[]?; .id==$id)' <<<"$current" >/dev/null; then
      curl_bearer_json "$token" "$payload" -fsS -H 'Content-Type: application/json' \
        "$open_webui_base/api/v1/skills/id/$id/update" >/dev/null
    else
      curl_bearer_json "$token" "$payload" -fsS -H 'Content-Type: application/json' \
        "$open_webui_base/api/v1/skills/create" >/dev/null
    fi
  done < <(jq -c '.[]' "$OPEN_WEBUI_ASSET_ROOT/skills.json")
}

sync_function() {
  local token="$1" id="$2" name="$3" source="$4" global="$5" content payload current
  content="$(cat "$source")"
  payload="$(jq -cn --arg id "$id" --arg name "$name" --arg content "$content" '{id:$id,name:$name,content:$content,meta:{description:"Managed explicitly by joshan-kana/.files"}}')"

  if curl_bearer "$token" -fsS "$open_webui_base/api/v1/functions/id/$id" >/dev/null 2>&1; then
    curl_bearer_json "$token" "$payload" -fsS -H 'Content-Type: application/json' \
      "$open_webui_base/api/v1/functions/id/$id/update" >/dev/null
  else
    curl_bearer_json "$token" "$payload" -fsS -H 'Content-Type: application/json' \
      "$open_webui_base/api/v1/functions/create" >/dev/null
  fi

  current="$(curl_bearer "$token" -fsS "$open_webui_base/api/v1/functions/id/$id")"
  if [[ "$(jq -r '.is_active' <<<"$current")" != true ]]; then
    curl_bearer "$token" -fsS -X POST "$open_webui_base/api/v1/functions/id/$id/toggle" >/dev/null
    current="$(curl_bearer "$token" -fsS "$open_webui_base/api/v1/functions/id/$id")"
  fi
  if [[ "$global" == true && "$(jq -r '.is_global' <<<"$current")" != true ]]; then
    curl_bearer "$token" -fsS -X POST "$open_webui_base/api/v1/functions/id/$id/toggle/global" >/dev/null
  fi
}

sync_notifications() {
  local token="$1" url targets url_file payload
  url="$(get_value "$open_webui_secret" OPEN_WEBUI_NOTIFICATION_WEBHOOK_URL)"
  [[ -n "$url" ]] || return 0
  targets="$(curl_bearer "$token" -fsS "$open_webui_base/api/v1/notifications/targets")"
  url_file="$(private_file "$url")"
  payload="$(jq -cn --arg id "$notification_id" --rawfile url "$url_file" '{id:$id,type:"webhook",enabled:true,events:["chat.finished","chat.failed"],delivery:"away",config:{url:$url}}')"

  if jq -e --arg id "$notification_id" 'any(.targets[]?; .id==$id)' <<<"$targets" >/dev/null; then
    curl_bearer_json "$token" "$payload" -fsS -X PUT -H 'Content-Type: application/json' \
      "$open_webui_base/api/v1/notifications/targets/$notification_id" >/dev/null
  else
    curl_bearer_json "$token" "$payload" -fsS -H 'Content-Type: application/json' \
      "$open_webui_base/api/v1/notifications/targets" >/dev/null
  fi
}

sync_openwebui() {
  wait_for "$open_webui_base/api/config" "Open WebUI"
  local token server_key
  token="$(openwebui_token)"
  server_key="$(get_value "$computer_secret" CPTR_GATEWAY_API_KEY)"
  : "${server_key:?Computer gateway key is missing; sync Computer first}"

  sync_openai_connections "$token" "$server_key"
  sync_tool_servers "$token"
  sync_folders "$token"
  sync_prompts "$token"
  sync_skills "$token"
  sync_function "$token" restart_recovery_filter "Restart Recovery Marker" "$OPEN_WEBUI_ASSET_ROOT/functions/restart_recovery_filter.py" true
  sync_function "$token" restart_recovery_event "Restart Recovery" "$OPEN_WEBUI_ASSET_ROOT/functions/restart_recovery_event.py" false
  sync_function "$token" compact_answer_filter "Compact Answer" "$OPEN_WEBUI_ASSET_ROOT/functions/compact_answer_filter.py" true
  sync_notifications "$token"
}

sync_all() {
  require_root
  [[ -f "$open_webui_secret" && -f "$searx_secret" && -f "$computer_secret" && -f "$github_secret" ]] || {
    echo "Required Open WebUI secrets are missing; run init-secrets and provision $github_secret." >&2
    return 1
  }
  [[ -n "$(get_value "$github_secret" GH_TOKEN)" ]] || {
    echo "$github_secret must define GH_TOKEN." >&2
    return 1
  }
  wait_for "http://127.0.0.1:${OPEN_WEBUI_AGENT_MAIL_PORT}/mail/" "Agent Mail Rust"
  sync_computer
  sync_openwebui
  echo "Open WebUI managed application settings are synchronized."

  [[ -n "$(get_value "$computer_secret" CPTR_MODEL_ID)" ]] || \
    echo "NOTE: no server Computer model is managed yet; configure one before autonomous-server validation." >&2
  [[ -n "$(get_value "$open_webui_secret" OPEN_WEBUI_NOTIFICATION_WEBHOOK_URL)" ]] || \
    echo "NOTE: unattended notification delivery is not configured yet." >&2
}

case "${1:---help}" in
  init-secrets) init_secrets ;;
  sync) sync_all ;;
  all) init_secrets; sync_all ;;
  -h|--help|help) usage ;;
  *) usage >&2; exit 2 ;;
esac