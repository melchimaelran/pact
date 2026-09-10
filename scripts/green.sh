#!/bin/sh
# Track the last "full suite green" per branch, so review and ship can skip an
# identical re-run.
#
#   pact green record <branch> <sha>   -> remember this branch is green at <sha>
#   pact green check  <branch> <sha>   -> exit 0 if the record matches, 1 otherwise
#   pact green show   <branch>         -> print the recorded sha (or nothing)
#
# Stored in .pact/green (gitignored via .pact/tmp? no — keep it committed-free):
# one `branch<TAB>sha<TAB>iso8601` line per branch.
set -eu
. "$(dirname "$0")/lib.sh"

d=$(pact_dir) || pact_die "not a PACT project"
f="$d/green"
touch "$f"

op=${1:-}; br=${2:-}; sha=${3:-}
case "$op" in
  record)
    [ -n "$br" ] && [ -n "$sha" ] || pact_die "usage: pact green record <branch> <sha>"
    grep -v "^${br}	" "$f" > "$f.tmp" 2>/dev/null || true
    printf '%s\t%s\t%s\n' "$br" "$sha" "$(date -u +%FT%TZ)" >> "$f.tmp"
    mv "$f.tmp" "$f"
    echo "ok"
    ;;
  check)
    [ -n "$br" ] && [ -n "$sha" ] || pact_die "usage: pact green check <branch> <sha>"
    rec=$(grep "^${br}	" "$f" | head -n1 | cut -f2)
    [ "$rec" = "$sha" ]
    ;;
  show)
    [ -n "$br" ] || pact_die "usage: pact green show <branch>"
    grep "^${br}	" "$f" | head -n1 | cut -f2
    ;;
  *)
    echo "usage: pact green {record|check|show} ..." >&2; exit 2 ;;
esac
