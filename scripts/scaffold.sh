#!/bin/sh
# pact scaffold  -> create the .pact/ + tasks/ + docs/ directory skeleton for the
# current project, ensure the .claude/settings.json enabledPlugins entry, ensure
# the CLAUDE.md PACT section, and ensure the managed .gitignore block.
#
# It does NOT write config.toml / stack.toml / project.md / constitution.md —
# `pact init` writes those with real values gathered from the questionnaire.
#
# Idempotent: safe to re-run.
set -eu
. "$(dirname "$0")/lib.sh"

root=$(pact_project_root) || pact_die "not in a git repo — run 'git init' first"

mkdir -p "$root/.pact" \
         "$root/tasks" \
         "$root/docs/specs" \
         "$root/docs/decisions"

[ -f "$root/.pact/charter-overrides.log" ] || : > "$root/.pact/charter-overrides.log"
[ -f "$root/tasks/.gitkeep" ] || : > "$root/tasks/.gitkeep"

# --- .claude/settings.json enabledPlugins -----------------------------------
mkdir -p "$root/.claude"
s="$root/.claude/settings.json"
if [ ! -f "$s" ]; then
  printf '{\n  "enabledPlugins": {\n    "pact@pact": true\n  }\n}\n' > "$s"
elif ! grep -q '"pact@pact"' "$s"; then
  # naive insert: add the key into an existing enabledPlugins object, or add the object
  if grep -q '"enabledPlugins"' "$s"; then
    sed -i.bak 's/"enabledPlugins"[[:space:]]*:[[:space:]]*{/"enabledPlugins": {\n    "pact@pact": true,/' "$s" && rm -f "$s.bak"
  else
    sed -i.bak 's/^{/{\n  "enabledPlugins": { "pact@pact": true },/' "$s" && rm -f "$s.bak"
  fi
fi

# --- CLAUDE.md PACT section -------------------------------------------------
c="$root/CLAUDE.md"
BEGIN='<!-- PACT:begin -->'
END='<!-- PACT:end -->'
if [ ! -f "$c" ] || ! grep -qF "$BEGIN" "$c"; then
  had_claude=0; [ -s "$c" ] && had_claude=1
  {
    [ "$had_claude" = 1 ] && printf '\n'
    printf '%s\n' "$BEGIN"
    printf '## PACT\n\n'
    printf 'This project uses PACT (spec-driven: spec -> plan -> build -> ship).\n'
    printf 'Config in `.pact/`. Run `/pact:status` for state, `/pact:spec <type> "..."` to start work.\n'
    printf '%s\n' "$END"
  } >> "$c"
fi

# --- .gitignore managed block --------------------------------------------
sh "$PACT_SCRIPTS/gitignore.sh" >/dev/null

echo "ok: scaffolded .pact/ tasks/ docs/ + .claude/settings.json + CLAUDE.md + .gitignore"
