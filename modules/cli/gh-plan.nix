{
  lib,
  pkgs,
  fields ? [
    "Status"
    "Priority"
    "Area"
    "Kind"
  ],
}:

let
  fieldsCsv = lib.concatStringsSep "," fields;
in
pkgs.writeShellApplication {
  name = "gh-plan";

  runtimeInputs = with pkgs; [
    bash
    coreutils
    fzf
    gawk
    gh
    git
    gnused
    jq
    less
  ];

  text = ''
    set -euo pipefail

    owner="''${GH_PLAN_OWNER:-}"
    project="''${GH_PLAN_PROJECT:-}"
    fields_csv=${lib.escapeShellArg fieldsCsv}
    fields_csv="''${GH_PLAN_FIELDS:-$fields_csv}"
    start_dir="''${GH_PLAN_START_DIR:-$PWD}"
    self="$0"
    export GH_PLAN_FIELDS="$fields_csv" GH_PLAN_START_DIR="$start_dir" GH_PLAN_SELF="$self"

    usage() {
      cat <<'USAGE'
    Usage: gh-plan [--owner OWNER] [--project NUMBER]

    Keyboard-first GitHub planning UI.

    With no flags, choose from the authenticated user's Projects. Use
    --owner for an organization or another Project owner. Project items may
    come from any repository you can access.

      j/k, arrows  move
      /            filter
      Esc          leave filter, then back/exit
      f            edit Project field
      i            edit issue relationships
      d            view pull-request diff
      v            open full issue/PR view
      o            open in browser
      c            checkout pull request in local repository
      Ctrl-r       refresh
      ?            help
      q            quit
    USAGE
    }

    picker_bindings() {
      # shellcheck disable=SC2016 # Expanded by fzf's transform subprocess.
      printf '%s' 'start:disable-search,j:down,k:up,q:abort,/:enable-search+unbind(j,k,q,f,i,d,v,o,c,?,/),esc:transform:[[ "$FZF_INPUT_STATE" == enabled ]] && echo "disable-search+rebind(j,k,q,f,i,d,v,o,c,?,/)+clear-query" || echo abort'
    }

    pick() {
      local prompt=$1
      fzf --layout=reverse --border --height='~80%' --prompt="$prompt" \
        --bind="$(picker_bindings)"
    }

    repo_from_url() {
      local url=$1
      if [[ $url =~ ^https?://[^/]+/([^/]+/[^/]+)/(issues|pull)/ ]]; then
        printf '%s\n' "''${BASH_REMATCH[1]}"
      else
        return 1
      fi
    }

    resolve_project() {
      local projects count selected

      if [[ -z $owner ]]; then
        owner=$(gh api user --jq .login)
      elif [[ $owner == '@me' ]]; then
        owner=$(gh api user --jq .login)
      fi

      if [[ -z $project ]]; then
        projects=$(gh project list --owner "$owner" --limit 100 --format json)
        count=$(jq '.projects | length' <<<"$projects")
        if (( count == 0 )); then
          printf 'No open GitHub Projects found for %s. Use --owner or --project to select another Project.\n' "$owner" >&2
          return 1
        elif (( count == 1 )); then
          selected=$(jq -r '.projects[0] | [(.number|tostring), .title, .owner.login] | @tsv' <<<"$projects")
        else
          selected=$(jq -r '.projects[] | [(.number|tostring), .title, .owner.login, ((.items.totalCount // 0)|tostring)] | @tsv' <<<"$projects"             | fzf --layout=reverse --border --height='~80%' --delimiter=$'\t' --with-nth=1,2,3,4                 --header='Number  Project  Owner  Items' --prompt='Project › ' --bind="$(picker_bindings)") || return 1
        fi
        IFS=$'\t' read -r project _ owner _ <<<"$selected"
      fi

      export GH_PLAN_OWNER="$owner" GH_PLAN_PROJECT="$project"
    }

    item_kind() {
      case "$1" in
        */issues/*) printf 'issue\n' ;;
        */pull/*) printf 'pr\n' ;;
        *) return 1 ;;
      esac
    }

    rows() {
      local fields_json
      fields_json=$(jq -cn --arg fields "$fields_csv" '$fields | split(",") | map(gsub("^[[:space:]]+|[[:space:]]+$"; ""))')
      gh project item-list "$project" --owner "$owner" --limit 500 --format json |
        jq -r --argjson fields "$fields_json" '
          def value($item; $field):
            ($field | ascii_downcase) as $key |
            ($item[$key] // "—") |
            if type == "array" then join(", ") else tostring end;
          (["URL", "Type", "Repository", "#"] + $fields + ["Title"] | @tsv),
          (.items[]
            | select(.content.url? != null)
            | . as $item
            | ([
                $item.content.url,
                $item.content.type,
                ($item.content.repository),
                ("#" + ($item.content.number | tostring))
              ]
              + [$fields[] as $field | value($item; $field)]
              + [$item.content.title]
              | @tsv))
        '
    }

    preview_issue() {
      local url=$1
      sleep 0.08
      gh issue view "$url" --json number,title,state,author,assignees,labels,body,url,parent,subIssues,subIssuesSummary,blockedBy,blocking |
        jq -r '
          def person: .login // .name // "?";
          def rel($label; $rel):
            if ($rel.totalCount // 0) == 0 then empty
            else "\n" + $label + ":\n" + ($rel.nodes | map("  " + (if .state == "CLOSED" then "✓" else "○" end) + " #" + (.number|tostring) + " " + .title) | join("\n"))
            end;
          "#\(.number)  \(.title)",
          "\(.state)  @\(.author.login)",
          (if (.assignees|length)>0 then "Assignees: " + ([.assignees[]|person]|join(", ")) else empty end),
          (if (.labels|length)>0 then "Labels: " + ([.labels[].name]|join(", ")) else empty end),
          (if .parent then "\nParent:\n  " + (if .parent.state == "CLOSED" then "✓" else "○" end) + " #" + (.parent.number|tostring) + " " + .parent.title else empty end),
          rel("Sub-issues (\(.subIssuesSummary.completed)/\(.subIssuesSummary.total))"; .subIssues),
          rel("Blocked by"; .blockedBy),
          rel("Blocking"; .blocking),
          "\n" + (.body // "")
        '
    }

    preview_pr() {
      local url=$1
      sleep 0.08
      gh pr view "$url" --json number,title,state,isDraft,author,assignees,labels,body,headRefName,baseRefName,reviewDecision,mergeStateStatus,url |
        jq -r '
          "#\(.number)  \(.title)",
          ((if .isDraft then "DRAFT" else .state end) + "  @" + .author.login),
          "\(.headRefName) → \(.baseRefName)",
          (if .reviewDecision then "Review: " + .reviewDecision else empty end),
          (if .mergeStateStatus then "Merge: " + .mergeStateStatus else empty end),
          (if (.assignees|length)>0 then "Assignees: " + ([.assignees[].login]|join(", ")) else empty end),
          (if (.labels|length)>0 then "Labels: " + ([.labels[].name]|join(", ")) else empty end),
          "\n" + (.body // "")
        '
    }

    preview() {
      local url=$1
      case "$(item_kind "$url")" in
        issue) preview_issue "$url" ;;
        pr) preview_pr "$url" ;;
      esac
    }

    field_options() {
      local field=$1
      gh project field-list "$project" --owner "$owner" --limit 100 --format json |
        jq -r --arg field "$field" '
          .fields[] | select(.name == $field) |
          if .type == "ProjectV2SingleSelectField" then
            (.options[]?.name), "<clear>"
          else
            "<clear>"
          end
        '
    }

    project_field_value() {
      local url=$1 field=$2
      gh project item-list "$project" --owner "$owner" --limit 500 --format json |
        jq -er --arg url "$url" --arg field "$field" '
          first(.items[] | select(.content.url == $url)) as $item
          | if $item == null then error("Project item not found")
            else ($item[($field | ascii_downcase)] // "")
            end
        '
    }

    verify_project_field() {
      local url=$1 field=$2 expected=$3 current attempt
      for (( attempt = 0; attempt < 5; attempt++ )); do
        current=$(project_field_value "$url" "$field")
        if [[ $current == "$expected" ]]; then
          return 0
        fi
        sleep 0.25
      done
      printf 'Project field verification failed: %s expected %q, got %q.\n' "$field" "$expected" "$current" >&2
      return 1
    }

    edit_field() {
      local url=$1 field value expected
      field=$(printf '%s\n' "$fields_csv" | tr ',' '\n' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | pick 'Field › ') || return 0
      [[ -n $field ]] || return 0

      value=$(field_options "$field" | pick "$field › ") || return 0
      [[ -n $value ]] || return 0

      if [[ $value == '<clear>' ]]; then
        gh project item-edit "$project" --owner "$owner" --url "$url" --field "$field" --clear >/dev/null
        expected=""
      else
        gh project item-edit "$project" --owner "$owner" --url "$url" --field "$field" --value "$value" >/dev/null
        expected=$value
      fi

      verify_project_field "$url" "$field" "$expected"
    }

    relationship_json() {
      gh issue view "$1" --json parent,subIssues,subIssuesSummary,blockedBy,blocking
    }

    relation_existing_rows() {
      local url=$1 relation=$2
      relationship_json "$url" |
        jq -r --arg relation "$relation" '
          if $relation == "parent" then
            if .parent then [.parent.url, ("#"+(.parent.number|tostring)), .parent.state, .parent.title] | @tsv else empty end
          else
            .[$relation].nodes[]? | [.url, ("#"+(.number|tostring)), .state, .title] | @tsv
          end
        '
    }

    candidate_rows_repo() {
      local repo=$1
      gh issue list -R "$repo" --state all --limit 200 --json number,title,state,url |
        jq -r '.[] | [.url, ("#"+(.number|tostring)), .state, .title] | @tsv'
    }

    candidate_rows_project() {
      gh project item-list "$project" --owner "$owner" --limit 500 --format json |
        jq -r '.items[] | select(.content.type == "Issue") | [.content.url, ("#"+(.content.number|tostring)), (.content.state // ""), .content.title] | @tsv'
    }

    search_global() {
      local query=''${1:-}
      local -a query_args
      [[ -n $query ]] || return 0
      read -r -a query_args <<<"$query"
      (( ''${#query_args[@]} > 0 )) || return 0
      gh search issues "''${query_args[@]}" --limit 100 --json number,repository,state,title,url 2>/dev/null |
        jq -r '.[] | [.url, .repository.nameWithOwner, ("#"+(.number|tostring)), .state, .title] | @tsv' || true
    }

    filter_excluded() {
      local excluded=''${GH_PLAN_EXCLUDE_URLS:-}
      awk -F '\t' -v excluded="$excluded" '
        BEGIN { n=split(excluded,a,"\n"); for(i=1;i<=n;i++) if(a[i]!="") x[a[i]]=1 }
        !($1 in x)
      '
    }

    target_picker() {
      local issue_url=$1 relation=$2 repo scope='Repo' query="" result key selected temp
      repo=$(repo_from_url "$issue_url")

      local excluded="$issue_url"
      while IFS= read -r row; do
        [[ -n $row ]] && excluded+=$'\n'"''${row%%$'\t'*}"
      done < <(relation_existing_rows "$issue_url" "$relation")
      export GH_PLAN_EXCLUDE_URLS="$excluded"

      while true; do
        temp=$(mktemp)
        case "$scope" in
          Repo) candidate_rows_repo "$repo" | filter_excluded >"$temp" ;;
          Project) candidate_rows_project | filter_excluded >"$temp" ;;
          All) : >"$temp" ;;
        esac

        if [[ $scope == All ]]; then
          result=$(fzf --layout=reverse --border --height='~80%' --delimiter=$'\t' --with-nth=2.. \
            --prompt='Target › ' --header="Scope: $scope · Tab changes scope" --print-query --expect=tab \
            --query="$query" --phony \
            --bind="$(picker_bindings),change:reload($self _search-global {q} | $self _filter-excluded)" <"$temp") || {
              rm -f "$temp"
              return 1
            }
        else
          result=$(fzf --layout=reverse --border --height='~80%' --delimiter=$'\t' --with-nth=2.. \
            --prompt='Target › ' --header="Scope: $scope · Tab changes scope" --print-query --expect=tab \
            --query="$query" --bind="$(picker_bindings)" <"$temp") || {
              rm -f "$temp"
              return 1
            }
        fi
        rm -f "$temp"

        query=$(printf '%s\n' "$result" | sed -n '1p')
        key=$(printf '%s\n' "$result" | sed -n '2p')
        selected=$(printf '%s\n' "$result" | sed -n '3p')
        if [[ $key == tab ]]; then
          case "$scope" in
            Repo) scope='Project' ;;
            Project) scope='All' ;;
            All) scope='Repo' ;;
          esac
          continue
        fi
        [[ -n $selected ]] || return 1
        printf '%s\n' "''${selected%%$'\t'*}"
        return 0
      done
    }

    relation_contains() {
      local issue_url=$1 relation=$2 target=$3 json status
      json=$(relationship_json "$issue_url") || return 2
      if jq -e --arg relation "$relation" --arg target "$target" '
        if $relation == "parent" then
          (.parent.url // "") == $target
        else
          any(.[$relation].nodes[]?; .url == $target)
        end
      ' <<<"$json" >/dev/null; then
        return 0
      else
        status=$?
        (( status == 1 )) && return 1
        return 2
      fi
    }

    verify_relation_state() {
      local issue_url=$1 relation=$2 target=$3 expected=$4 attempt present status
      for (( attempt = 0; attempt < 5; attempt++ )); do
        if relation_contains "$issue_url" "$relation" "$target"; then
          present=true
        else
          status=$?
          if (( status == 2 )); then
            printf 'Relationship verification read failed for %s -> %s.\n' "$relation" "$target" >&2
            return 1
          fi
          present=false
        fi
        if [[ $present == "$expected" ]]; then
          return 0
        fi
        sleep 0.25
      done
      printf 'Relationship verification failed: %s -> %s expected present=%s.\n' "$relation" "$target" "$expected" >&2
      return 1
    }

    remove_relation() {
      local issue_url=$1 relation=$2 flag=$3 row target
      if [[ $relation == parent ]]; then
        row=$(relation_existing_rows "$issue_url" "$relation")
        [[ -n $row ]] || return 0
        target=''${row%%$'\t'*}
        gh issue edit "$issue_url" "$flag" >/dev/null
        verify_relation_state "$issue_url" "$relation" "$target" false
        return
      fi
      row=$(relation_existing_rows "$issue_url" "$relation" | fzf --layout=reverse --border --height='~60%' --delimiter=$'\t' --with-nth=2.. --prompt='Remove › ' --bind="$(picker_bindings)") || return 0
      [[ -n $row ]] || return 0
      target=''${row%%$'\t'*}
      gh issue edit "$issue_url" "$flag" "$target" >/dev/null
      verify_relation_state "$issue_url" "$relation" "$target" false
    }

    add_relation() {
      local issue_url=$1 relation=$2 flag=$3 target
      target=$(target_picker "$issue_url" "$relation") || return 0
      gh issue edit "$issue_url" "$flag" "$target" >/dev/null
      verify_relation_state "$issue_url" "$relation" "$target" true
    }

    relationships() {
      local url=$1 choice action relation flag
      [[ $(item_kind "$url") == issue ]] || return 0

      while true; do
        choice=$(cat <<'ACTIONS' | pick 'Relationships › '
    Set parent	add	parent	--parent
    Remove parent	remove	parent	--remove-parent
    Add sub-issue	add	subIssues	--add-sub-issue
    Remove sub-issue	remove	subIssues	--remove-sub-issue
    Add blocked-by	add	blockedBy	--add-blocked-by
    Remove blocked-by	remove	blockedBy	--remove-blocked-by
    Add blocking	add	blocking	--add-blocking
    Remove blocking	remove	blocking	--remove-blocking
    ACTIONS
        ) || return 0
        [[ -n $choice ]] || return 0
        IFS=$'\t' read -r _ action relation flag <<<"$choice"

        if [[ $action == add ]]; then
          add_relation "$url" "$relation" "$flag"
        else
          remove_relation "$url" "$relation" "$flag"
        fi

        return 0
      done
    }

    view_item() {
      case "$(item_kind "$1")" in
        issue) gh issue view "$1" ;;
        pr) gh pr view "$1" ;;
      esac
    }

    open_web() {
      case "$(item_kind "$1")" in
        issue) gh issue view "$1" --web ;;
        pr) gh pr view "$1" --web ;;
      esac
    }

    pr_diff() {
      local url=$1 pager
      [[ $(item_kind "$url") == pr ]] || return 0
      pager=$(git -C "$start_dir" config --get pager.diff 2>/dev/null         || git -C "$start_dir" config --get core.pager 2>/dev/null         || git config --global --get pager.diff 2>/dev/null         || git config --global --get core.pager 2>/dev/null         || true)
      [[ -n $pager ]] || pager='cat'
      gh pr diff "$url" | sh -c "$pager"
    }

    checkout_pr() {
      local url=$1 repo current_repo
      [[ $(item_kind "$url") == pr ]] || return 0
      repo=$(repo_from_url "$url")
      current_repo=$(cd "$start_dir" && gh repo view --json nameWithOwner --jq .nameWithOwner 2>/dev/null || true)
      if [[ $current_repo != "$repo" ]]; then
        printf 'Checkout requires starting gh-plan from a local clone of %s (current: %s).\n'           "$repo" "''${current_repo:-not a GitHub repository}" >&2
        return 1
      fi
      (cd "$start_dir" && gh pr checkout "$url" -R "$repo")
    }

    help_screen() {
      usage | less -R
    }

    main_ui() {
      export GH_PLAN_SELF="$self"
      rows | fzf --ansi --layout=reverse --border --delimiter=$'\t' --with-nth=2.. --header-lines=1 \
        --prompt='GitHub › ' --preview="$self _preview {1}" --preview-window='right,60%,wrap' \
        --bind="ctrl-r:reload($self _rows),f:execute($self _edit-field {1})+reload($self _rows),i:execute($self _relationships {1})+reload($self _rows),d:execute($self _diff {1}),v:execute($self _view {1}),o:execute-silent($self _open {1}),c:execute($self _checkout {1}),?:execute($self _help),$(picker_bindings)" >/dev/null || true
    }

    while [[ $# -gt 0 ]]; do
      case "$1" in
        --owner) owner=$2; export GH_PLAN_OWNER="$owner"; shift 2 ;;
        --project) project=$2; export GH_PLAN_PROJECT="$project"; shift 2 ;;
        -h|--help) usage; exit 0 ;;
        _rows) resolve_project; rows; exit ;;
        _preview) preview "$2"; exit ;;
        _edit-field) resolve_project; edit_field "$2"; exit ;;
        _relationships) resolve_project; relationships "$2"; exit ;;
        _search-global) search_global "''${2:-}"; exit ;;
        _filter-excluded) filter_excluded; exit ;;
        _diff) pr_diff "$2"; exit ;;
        _view) view_item "$2"; exit ;;
        _open) open_web "$2"; exit ;;
        _checkout) checkout_pr "$2"; exit ;;
        _help) help_screen; exit ;;
        *) printf 'Unknown argument: %s\n' "$1" >&2; usage >&2; exit 2 ;;
      esac
    done

    resolve_project
    main_ui
  '';
}
