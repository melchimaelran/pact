#!/bin/sh
# Main status line renderer. Reads the Claude Code statusline JSON on stdin
# and prints one line: model, dir, context-window usage — plus, inside a PACT
# project, flow mode, project name, and the spec/story/worktree progress.
# Zero model tokens: pure shell against JSON Claude Code already handed it.
#
# Install into user or project settings.json via `/pact:config statusline install`.
# If you already have a statusLine, pipe the same stdin through this and splice
# its output in as one segment.
set -eu

dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
. "$dir/lib.sh"

json=$(cat)

model=$(printf '%s' "$json" | pact_json_get display_name)
cwd=$(printf '%s' "$json" | pact_json_get cwd)
pct=$(printf '%s' "$json" | pact_json_get used_percentage)

[ -n "$cwd" ] && [ "$cwd" != null ] && [ -d "$cwd" ] && cd "$cwd" 2>/dev/null || true

segs=''
[ -n "$model" ] && [ "$model" != null ] && segs="$model"

if [ -n "$cwd" ] && [ "$cwd" != null ]; then
  short="${cwd##*/}"
  segs="${segs:+$segs · }$short"
fi

if [ -n "$pct" ] && [ "$pct" != null ]; then
  pct_i=$(printf '%.0f' "$pct" 2>/dev/null) || pct_i=$pct
  segs="${segs:+$segs · }ctx ${pct_i}%"
fi

d=$(pact_dir 2>/dev/null || true)
if [ -n "$d" ]; then
  root=$(pact_project_root)
  proj="${root##*/}"
  flow=$(pact_toml_get_in "$d/config.toml" mode flow 2>/dev/null || true)
  segs="${segs:+$segs · }PACT${flow:+ [$flow]} $proj"

  spec=$(sh "$dir/status.sh" --oneline 2>/dev/null || true)
  spec="${spec#PACT }"
  [ -n "$spec" ] && segs="${segs} · ${spec}"
fi

printf '%s\n' "$segs"
