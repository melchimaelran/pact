#!/bin/sh
# pact adr-id  -> print the next free NNNN for docs/decisions/NNNN-*.md
set -eu
. "$(dirname "$0")/lib.sh"
root=$(pact_project_root) || pact_die "not in a git repo"
max=0
for f in "$root"/docs/decisions/[0-9]*.md; do
  [ -f "$f" ] || continue
  n=$(basename "$f" | sed -n 's/^\([0-9][0-9]*\)-.*/\1/p')
  n=$(printf '%s' "$n" | sed 's/^0*//'); [ -n "$n" ] || n=0
  [ "$n" -gt "$max" ] && max=$n
done
printf '%04d\n' "$((max + 1))"
