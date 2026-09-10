#!/bin/sh
# SessionStart hook. Zero model tokens. Silent outside a PACT project.
# Prints, at most, a handful of lines: schema notice, plugin-enable hint,
# condensed project state, light drift flags, uncommitted-.pact note.
set -eu
. "$(dirname "$0")/lib.sh"

d=$(pact_dir) || exit 0            # not a PACT project -> say nothing
root=$(pact_project_root)

# --- schema gate notice ---------------------------------------------------------
have=$(pact_schema)
if [ "$have" != "$PACT_SUPPORTED_SCHEMA" ]; then
  echo "⚠ PACT: .pact schema $have, plugin $PACT_SUPPORTED_SCHEMA — run /pact:migrate before any write command."
fi

# --- plugin-enabled hint (passive; never blocks) ------------------------------
settings="$root/.claude/settings.json"
if [ -f "$settings" ] && ! grep -q '"pact@pact"' "$settings" 2>/dev/null; then
  echo "PACT: this project has .pact/ but the plugin is not enabled here — add \"pact@pact\": true to .claude/settings.json enabledPlugins."
fi

# --- condensed project state --------------------------------------------------
# Delegates to the status renderer in --oneline mode when available.
if [ -x "$PACT_SCRIPTS/status.sh" ] || [ -f "$PACT_SCRIPTS/status.sh" ]; then
  sh "$PACT_SCRIPTS/status.sh" --oneline 2>/dev/null || true
fi

# --- light drift flag --------------------------------------------------------
# A cheap heuristic only: a stories index older than any story file.
for idx in "$root"/tasks/*/STORIES_INDEX.md; do
  [ -f "$idx" ] || continue
  newer=$(find "$(dirname "$idx")/epics" -name '*.md' -newer "$idx" 2>/dev/null | head -n1 || true)
  [ -n "$newer" ] && { echo "PACT: an index looks stale — run /pact:check."; break; }
done

# --- uncommitted .pact note --------------------------------------------------
if [ -n "$root" ] && ! git -C "$root" diff --quiet -- .pact 2>/dev/null; then
  echo "PACT: .pact/ has uncommitted changes."
fi

exit 0
