#!/bin/sh
# pact check [--quiet]  -> project health report; names the fix for each finding.
# Exit 1 if any ERROR-level finding exists, else 0.
set -eu
. "$(dirname "$0")/lib.sh"

root=$(pact_project_root 2>/dev/null || true)
[ -n "$root" ] && [ -d "$root/.pact" ] || { echo "not a PACT project"; exit 0; }

quiet=0; [ "${1:-}" = "--quiet" ] && quiet=1

W=$(mktemp -d); trap 'rm -rf "$W"' EXIT
: > "$W/err"; : > "$W/warn"; : > "$W/ok"
err()  { printf 'ERROR  %s  -> %s\n' "$1" "$2" >> "$W/err"; }
warn() { printf 'WARN   %s  -> %s\n' "$1" "$2" >> "$W/warn"; }
ok()   { printf 'ok     %s\n' "$1" >> "$W/ok"; }

# --- schema ---------------------------------------------------------------
have=$(pact_schema)
if [ "$have" = "$PACT_SUPPORTED_SCHEMA" ]; then ok "schema $have"
else err "schema $have != plugin $PACT_SUPPORTED_SCHEMA" "/pact:migrate"; fi

# --- .gitignore block --------------------------------------------------
if sh "$PACT_SCRIPTS/gitignore.sh" --check >/dev/null 2>&1; then ok ".gitignore managed block"
else err ".gitignore managed block missing or .pact/ ignored wholesale" "pact gitignore"; fi

# --- collect all story ids ---------------------------------------------
: > "$W/ids"
find "$root/tasks" -path '*/stories/*.md' 2>/dev/null | sort > "$W/stories"
while read -r s; do
  [ -n "$s" ] || continue
  id=$(fm_get "$s" id)
  if [ -z "$id" ]; then
    err "${s#"$root"/}: unparseable frontmatter (no id)" "fix the frontmatter, then pact views"
  else
    echo "$id" >> "$W/ids"
  fi
done < "$W/stories"

# --- unresolvable blocked_by -----------------------------------------
while read -r s; do
  [ -n "$s" ] || continue
  for dep in $(fm_get "$s" blocked_by | sed 's/[][",]/ /g'); do
    [ -n "$dep" ] || continue
    grep -qx "$dep" "$W/ids" 2>/dev/null \
      || err "${s#"$root"/}: blocked_by '$dep' resolves to no story" "correct blocked_by or pact plan --quick"
  done
done < "$W/stories"

# --- view drift ---------------------------------------------------------
for si in "$root"/tasks/*/STORIES_INDEX.md; do
  [ -f "$si" ] || continue
  newer=$(find "$(dirname "$si")/epics" -name '*.md' -newer "$si" 2>/dev/null | head -n1 || true)
  [ -n "$newer" ] && warn "index older than a story file: ${si#"$root"/}" "pact views"
done

# --- orphan spec branches --------------------------------------------
for b in $(git -C "$root" branch --format='%(refname:short)' 2>/dev/null | grep '^spec/' || true); do
  id=$(printf '%s' "$b" | sed -n 's#^spec/\(SP-[0-9]\{3\}\).*#\1#p')
  grep -ql "^id:[[:space:]]*$id" "$root"/docs/specs/*/spec.md 2>/dev/null \
    || warn "branch $b has no matching spec" "git branch -D $b, or restore the spec"
done

# --- uncommitted .pact ---------------------------------------------
git -C "$root" diff --quiet -- .pact 2>/dev/null || warn ".pact/ has uncommitted changes" "commit it"

# --- report ----------------------------------------------------------
ne=$(wc -l < "$W/err"  | tr -d ' ')
nw=$(wc -l < "$W/warn" | tr -d ' ')
if [ "$quiet" = 0 ]; then
  cat "$W/ok"
  cat "$W/warn"
fi
cat "$W/err"
[ "$quiet" = 0 ] && { echo; echo "$ne error(s), $nw warning(s)"; }
[ "$ne" -eq 0 ]
