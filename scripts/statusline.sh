#!/bin/sh
# Main status line renderer. Claude Code's own footer already shows model,
# cwd, and context-window usage (it renders alongside a custom statusLine,
# not instead of it) — this line stays PACT-only: flow mode, project name,
# spec/story/worktree progress, colored. Prints nothing outside a PACT
# project. Zero model tokens: pure shell against the JSON Claude Code hands
# the command on stdin.
#
# Install into user or project settings.json via `/pact:config statusline install`.
set -eu

dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
. "$dir/lib.sh"

json=$(cat)
cwd=$(printf '%s' "$json" | pact_json_get cwd)
[ -n "$cwd" ] && [ "$cwd" != null ] && [ -d "$cwd" ] && cd "$cwd" 2>/dev/null || true

d=$(pact_dir 2>/dev/null || true)
[ -n "$d" ] || exit 0

root=$(pact_project_root)
proj="${root##*/}"
flow=$(pact_toml_get_in "$d/config.toml" mode flow 2>/dev/null || true)

bold=$(printf '\033[1m');  reset=$(printf '\033[0m')
cyan=$(printf '\033[36m'); dim=$(printf '\033[2m')
yellow=$(printf '\033[33m'); blue=$(printf '\033[34m')

case "$flow" in
  full) mcolor=$yellow ;;
  lite) mcolor=$blue ;;
  *)    mcolor=$dim ;;
esac

line="${bold}${cyan}PACT${reset}"
[ -n "$flow" ] && [ "$flow" != null ] && line="$line ${mcolor}[${flow}]${reset}"
line="$line ${bold}${proj}${reset}"

spec=$(sh "$dir/status.sh" --oneline 2>/dev/null || true)
spec="${spec#PACT }"
[ -n "$spec" ] && line="$line ${dim}·${reset} $spec"

printf '%s\n' "$line"
