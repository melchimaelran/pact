#!/bin/sh
# Main status line renderer. Reads the Claude Code statusline JSON on stdin,
# prints one PACT line, or nothing outside a PACT project. Zero model tokens.
#
# Install into user or project settings.json via `/pact:config statusline install`.
# If you already have a statusLine, pipe the same stdin through this and splice
# its output in as one segment — it is silent when not in a PACT project.
set -eu

dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
cat >/dev/null 2>&1 || true   # consume stdin; we only need the cwd
exec sh "$dir/status.sh" --oneline
