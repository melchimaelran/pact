#!/bin/sh
# pact story set <story-file> <key=value> [<key=value>...]   -> update frontmatter, regen views
# pact story get <story-file> <key>                          -> print one frontmatter value
#
# The single mutation path for story state: writes frontmatter, then runs
# `pact views` so the indexes can never drift.
set -eu
. "$(dirname "$0")/lib.sh"

op=${1:-}; shift 2>/dev/null || true
case "$op" in
  get)
    f=${1:-}; k=${2:-}
    [ -f "$f" ] && [ -n "$k" ] || pact_die "usage: pact story get <file> <key>"
    fm_get "$f" "$k"
    ;;
  set)
    f=${1:-}; shift 2>/dev/null || true
    [ -f "$f" ] || pact_die "usage: pact story set <file> <key=value>..."
    [ $# -ge 1 ] || pact_die "no key=value pairs"
    tmp=$(mktemp)
    cp "$f" "$tmp"
    for kv in "$@"; do
      k=${kv%%=*}; v=${kv#*=}
      case "$kv" in *=*) : ;; *) pact_die "bad pair: $kv" ;; esac
      # replace the key inside the frontmatter block only (lines 2..second ---)
      awk -v k="$k" -v v="$v" '
        NR==1 && $0=="---" {print; infm=1; next}
        infm && $0=="---" {infm=0; if(!done){print k": "v}; print; next}
        infm && $0 ~ "^[[:space:]]*"k"[[:space:]]*:" {print k": "v; done=1; next}
        {print}
      ' "$tmp" > "$tmp.2" && mv "$tmp.2" "$tmp"
    done
    mv "$tmp" "$f"
    sh "$PACT_SCRIPTS/views.sh" >/dev/null
    echo "ok: updated $(basename "$f"), views regenerated"
    ;;
  *)
    echo "usage: pact story {set|get} ..." >&2; exit 2 ;;
esac
