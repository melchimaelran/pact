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
# Never risk corrupting the user's Claude Code settings. Use a real JSON editor
# when one is available; otherwise leave the file untouched and tell the user the
# one line to add.
mkdir -p "$root/.claude"
s="$root/.claude/settings.json"

json_editor=''
if command -v python3 >/dev/null 2>&1; then json_editor=python3
elif command -v node >/dev/null 2>&1; then json_editor=node
fi

if [ ! -f "$s" ]; then
  printf '{\n  "enabledPlugins": {\n    "pact@pact": true\n  }\n}\n' > "$s"
elif grep -q '"pact@pact"' "$s"; then
  : # already enabled
elif [ "$json_editor" = python3 ]; then
  python3 - "$s" <<'PY' || echo "pact: could not update $s automatically — add \"pact@pact\": true under enabledPlugins" >&2
import json, sys
p = sys.argv[1]
d = json.load(open(p))
d.setdefault("enabledPlugins", {})["pact@pact"] = True
json.dump(d, open(p, "w"), indent=2)
open(p, "a").write("\n")
PY
elif [ "$json_editor" = node ]; then
  node -e '
    const fs=require("fs"), p=process.argv[1];
    const d=JSON.parse(fs.readFileSync(p,"utf8"));
    (d.enabledPlugins ||= {})["pact@pact"]=true;
    fs.writeFileSync(p, JSON.stringify(d,null,2)+"\n");
  ' "$s" || echo "pact: could not update $s automatically — add \"pact@pact\": true under enabledPlugins" >&2
else
  echo "pact: no json tool (python3/node) found — add \"pact@pact\": true under enabledPlugins in $s by hand" >&2
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
