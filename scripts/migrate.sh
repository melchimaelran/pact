#!/bin/sh
# pact migrate  -> upgrade the project's .pact layout to the schema this plugin
# build supports. One-shot, idempotent, refuses a dirty tree, chained across
# versions, one revertable commit.
#
# Migration steps live in scripts/migrations/NNNN-*.sh and are applied in order
# for every version between the project's current schema and the supported one.
# Each step reads the project root as $1 and must be idempotent.
set -eu
. "$(dirname "$0")/lib.sh"

root=$(pact_project_root 2>/dev/null || true)
[ -n "$root" ] && [ -d "$root/.pact" ] || { echo "not a PACT project — nothing to migrate"; exit 0; }

have=$(pact_schema)
want=$PACT_SUPPORTED_SCHEMA

if [ "$have" = "$want" ]; then
  echo "ok: already at schema $want"
  exit 0
fi
if [ "$have" -gt "$want" ] 2>/dev/null; then
  pact_die "project schema $have is newer than this plugin ($want) — update the plugin"
fi

# refuse a dirty tree
git -C "$root" diff --quiet && git -C "$root" diff --cached --quiet \
  || pact_die "working tree is dirty — commit or stash first"

mdir="$PACT_SCRIPTS/migrations"
n=$have
while [ "$n" -lt "$want" ]; do
  next=$((n + 1))
  step=$(ls "$mdir"/$(printf '%04d' "$next")-*.sh 2>/dev/null | head -n1 || true)
  [ -n "$step" ] || pact_die "no migration step for schema $n -> $next"
  echo "applying schema $n -> $next : $(basename "$step")"
  sh "$step" "$root"
  n=$next
done

# stamp
sed -i.bak "s/^schema[[:space:]]*=.*/schema = $want/" "$root/.pact/config.toml" && rm -f "$root/.pact/config.toml.bak"
sh "$PACT_SCRIPTS/views.sh" >/dev/null

git -C "$root" add -A
git -C "$root" commit -m "chore(pact): migrate .pact schema $have -> $want" >/dev/null
echo "ok: migrated $have -> $want, committed"
