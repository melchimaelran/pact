#!/bin/sh
# pact wave-plan <plan-dir> [--epic NN] [--spec SP-NNN]
#
# Compute dependency-ordered waves for the non-done stories in scope. Waves are
# the topological layers of the blocked_by DAG; every story in a wave can run in
# parallel. Prints one wave per line, story ids space-separated:
#
#   wave 1: 01-01 01-03
#   wave 2: 01-02
#
# blocked_by edges to stories that are already `done` are satisfied and ignored.
# A cycle or an unresolvable id is an error (exit 1).
set -eu
. "$(dirname "$0")/lib.sh"

plan=${1:-}
[ -n "$plan" ] && [ -d "$plan/epics" ] || pact_die "usage: pact wave-plan <plan-dir> [--epic NN] [--spec SP-NNN]"
shift
epic_filter=''; spec_filter=''
while [ $# -gt 0 ]; do
  case "$1" in
    --epic) epic_filter=$2; shift 2 ;;
    --spec) spec_filter=$2; shift 2 ;;
    *) pact_die "unknown arg: $1" ;;
  esac
done

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

# collect stories in scope -> $work/nodes (id), $work/dep/<id> (blocked_by), $work/done (done ids)
: > "$work/nodes"; : > "$work/done"; mkdir "$work/dep"
find "$plan/epics" -name '*.md' -path '*/stories/*' | sort | while read -r s; do
  id=$(fm_get "$s" id); [ -n "$id" ] || continue
  st=$(fm_get "$s" status)
  ep=$(fm_get "$s" epic)
  sp=$(fm_get "$s" spec)
  [ -n "$epic_filter" ] && [ "$ep" != "$epic_filter" ] && continue
  [ -n "$spec_filter" ] && [ "$sp" != "$spec_filter" ] && continue
  if [ "$st" = done ] || [ "$st" = skip ]; then
    echo "$id" >> "$work/done"; continue
  fi
  echo "$id" >> "$work/nodes"
  fm_get "$s" blocked_by | sed 's/^\[//; s/\]$//; s/"//g; s/,/ /g' > "$work/dep/$id"
done

[ -s "$work/nodes" ] || { echo "no non-done stories in scope"; exit 0; }

# Kahn-style layering. A node is ready when every blocked_by id is done or already emitted.
emitted="$work/emitted"; : > "$emitted"
cat "$work/done" > "$emitted" 2>/dev/null || true
remaining=$(cat "$work/nodes")
wave=0
while [ -n "$remaining" ]; do
  wave=$((wave+1))
  ready=''
  for id in $remaining; do
    deps=$(cat "$work/dep/$id" 2>/dev/null || true)
    ok=1
    for d in $deps; do
      [ -n "$d" ] || continue
      grep -qx "$d" "$emitted" || { ok=0; break; }
    done
    [ "$ok" = 1 ] && ready="$ready $id"
  done
  ready=$(echo $ready)
  if [ -z "$ready" ]; then
    echo "pact: dependency cycle or unresolvable blocked_by among: $remaining" >&2
    exit 1
  fi
  echo "wave $wave:$(printf ' %s' $ready)"
  for id in $ready; do echo "$id" >> "$emitted"; done
  newrem=''
  for id in $remaining; do
    echo "$ready" | tr ' ' '\n' | grep -qx "$id" || newrem="$newrem $id"
  done
  remaining=$(echo $newrem)
done
