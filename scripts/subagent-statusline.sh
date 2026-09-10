#!/bin/sh
# Per-agent status row during build waves. Rendered by the terminal, zero model
# tokens. Reads the Claude Code statusline JSON on stdin. Prints one line, or
# nothing when there is nothing PACT-specific to show.
set -eu
. "$(dirname "$0")/lib.sh"

is_pact_project || exit 0

payload=$(cat 2>/dev/null || true)
# The agent's working branch tells us which story it is on.
branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || true)
case "$branch" in
  story/*|fix/*)
    id=$(printf '%s' "$branch" | sed -n 's#^\(story\|fix\)/\([0-9][0-9]*-[0-9][0-9]*\).*#\2#p')
    [ -n "$id" ] && printf 'PACT %s\n' "$id"
    ;;
  *) : ;;
esac
exit 0
