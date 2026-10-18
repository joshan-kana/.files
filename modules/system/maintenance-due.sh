# Run only if a scheduled calendar occurrence has not completed successfully.
set -euo pipefail

job=$1
interval=$2
time=$3
shift 3

state_dir=${MAINTENANCE_STATE_DIR:-/var/db/.files/maintenance}
now=${MAINTENANCE_NOW:-$(date +%s)}
today=$(date -d "@$now" +%F)

# A weekly schedule is Sunday-based. Other intervals step from the first
# day of each month, matching launchd's StartCalendarInterval exactly.
for ((back = 0; back <= 31; back++)); do
  day=$(date -d "$today 12:00 $back days ago" +%F)
  if ((interval == 7)); then
    [[ $(date -d "$day" +%u) == 7 ]] || continue
  else
    day_of_month=$(date -d "$day" +%-d)
    (((day_of_month - 1) % interval == 0)) || continue
  fi

  due=$(date -d "$day $time" +%s)
  ((due <= now)) && break
done

[[ -n ${due:-} && $due -le $now ]] || exit 1

stamp=$state_dir/$job
last=0
if [[ -f $stamp ]]; then
  read -r last < "$stamp" || true
  [[ $last =~ ^[0-9]+$ ]] || { echo "Invalid maintenance stamp: $stamp" >&2; exit 1; }
fi
((last < due)) || exit 0

"$@"
tmp=$(mktemp "$stamp.XXXXXX")
printf '%s\n' "$due" > "$tmp"
mv -f "$tmp" "$stamp"
