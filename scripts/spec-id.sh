#!/bin/sh
# pact spec-id  -> print the next free SP-NNN by scanning docs/specs/*/spec.md.
set -eu
. "$(dirname "$0")/lib.sh"

root=$(pact_project_root) || pact_die "not in a git repo"
max=0
for f in "$root"/docs/specs/*/spec.md; do
  [ -f "$f" ] || continue
  n=$(sed -n 's/^id:[[:space:]]*SP-\([0-9][0-9]*\).*/\1/p' "$f" | head -n1)
  [ -n "$n" ] || continue
  n=$(printf '%s' "$n" | sed 's/^0*//'); [ -n "$n" ] || n=0
  [ "$n" -gt "$max" ] && max=$n
done
next=$((max + 1))
printf 'SP-%03d\n' "$next"
