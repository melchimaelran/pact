#!/bin/sh
# pact status            -> the read-only dashboard
# pact status --oneline  -> a single condensed line (used by the SessionStart hook)
# pact status --write    -> also write tasks/ROADMAP.md as a generated snapshot
set -eu
. "$(dirname "$0")/lib.sh"

mode=full
case "${1:-}" in
  --oneline) mode=oneline ;;
  --write)   mode=write ;;
  "") : ;;
  *) echo "usage: pact status [--oneline|--write]" >&2; exit 2 ;;
esac

root=$(pact_project_root 2>/dev/null || true)
[ -n "$root" ] && [ -d "$root/.pact" ] || { [ "$mode" = oneline ] && exit 0; echo "not a PACT project"; exit 0; }

branch=$(git -C "$root" rev-parse --abbrev-ref HEAD 2>/dev/null || echo '-')
active=$(printf '%s' "$branch" | sed -n 's#^spec/\(SP-[0-9]\{3\}\)-.*#\1#p')

# counts from FEATURE_INDEX
fi="$root/tasks/FEATURE_INDEX.md"
specs=0; done_specs=0
if [ -f "$fi" ]; then
  specs=$(grep -c '^| SP-' "$fi" 2>/dev/null || echo 0)
  done_specs=$(awk -F'|' '/^\| SP-/ && $5 ~ /done/' "$fi" 2>/dev/null | wc -l | tr -d ' ')
fi

# active spec story progress
sp_done=0; sp_total=0; active_slug='-'
if [ -n "$active" ]; then
  for si in "$root"/tasks/*/STORIES_INDEX.md; do
    [ -f "$si" ] || continue
    grep -q "$active" "$root/docs/specs/"*/spec.md 2>/dev/null || true
  done
  for st in $(grep -rl "^spec:[[:space:]]*$active$" "$root"/tasks/*/epics/*/stories/*.md 2>/dev/null || true); do
    sp_total=$((sp_total+1))
    [ "$(fm_get "$st" status)" = done ] && sp_done=$((sp_done+1))
  done
  active_slug=$(printf '%s' "$branch" | sed -n 's#^spec/SP-[0-9]\{3\}-\(.*\)#\1#p')
fi

# live worktrees
wts=$(git -C "$root" worktree list 2>/dev/null | awk 'NR>1{print $NF}' | tr -d '[]' | paste -sd' ' - 2>/dev/null || true)

if [ "$mode" = oneline ]; then
  if [ -n "$active" ]; then
    line="PACT $active $active_slug $sp_done/$sp_total"
    [ -n "$wts" ] && line="$line · wt: $wts"
    echo "$line"
  else
    echo "PACT $done_specs/$specs specs"
  fi
  exit 0
fi

echo "PACT — $root"
echo
echo "Specs: $done_specs/$specs done"
[ -f "$fi" ] && { echo; sed -n '5,$p' "$fi"; }

if [ -n "$active" ]; then
  echo
  echo "Active spec: $active ($active_slug) — stories $sp_done/$sp_total"
  for si in "$root"/tasks/*/STORIES_INDEX.md; do
    [ -f "$si" ] || continue
    grep -q "| $active |" "$si" 2>/dev/null && { echo; sed -n '5,$p' "$si"; }
  done
fi

[ -n "$wts" ] && { echo; echo "Worktrees: $wts"; }
[ -f "$root/.pact/wave.lock" ] && { echo; echo "wave.lock:"; cat "$root/.pact/wave.lock"; }

if [ "$mode" = write ]; then
  {
    printf '# Roadmap\n\n<!-- generated snapshot: pact status --write -->\n\n'
    [ -f "$fi" ] && sed -n '5,$p' "$fi"
  } > "$root/tasks/ROADMAP.md"
  echo
  echo "wrote tasks/ROADMAP.md"
fi
