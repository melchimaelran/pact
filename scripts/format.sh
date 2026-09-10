#!/bin/sh
# PostToolUse(Write|Edit|MultiEdit) hook. Formats the file just written with the
# project's formatter, if one is configured and the file is inside the project.
# Config-gated, silent on success, never fails the tool call.
set -eu
. "$(dirname "$0")/lib.sh"

is_pact_project || exit 0

payload=$(cat)
file=$(printf '%s' "$payload" | sed -n 's/.*"file_path"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')
[ -n "$file" ] && [ -f "$file" ] || exit 0

d=$(pact_dir)
fmt=$(pact_toml_get "$d/stack.toml" format 2>/dev/null || true)
[ -n "$fmt" ] || exit 0          # no formatter configured -> nothing to do

# {path} placeholder, else append the path.
case "$fmt" in
  *'{path}'*) cmd=$(printf '%s' "$fmt" | sed "s#{path}#$file#g") ;;
  *)          cmd="$fmt $file" ;;
esac

( cd "$(pact_project_root)" && sh -c "$cmd" ) >/dev/null 2>&1 || true
exit 0
