#!/bin/sh
# Main status line renderer. Renders model | folder | full path | context
# usage | tokens (colored), then — inside a PACT project — a PACT segment:
# flow mode, project name, spec/story/worktree progress. Zero model tokens:
# pure shell against the JSON Claude Code hands the command on stdin.
#
# Install into user or project settings.json via `/pact:config statusline install`.
set -eu

dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
. "$dir/lib.sh"

json=$(cat)

model=$(printf '%s' "$json" | pact_json_get display_name)
cwd=$(printf '%s' "$json" | pact_json_get cwd)
pct=$(printf '%s' "$json" | pact_json_get used_percentage)
tin=$(printf '%s' "$json" | pact_json_get total_input_tokens)
tout=$(printf '%s' "$json" | pact_json_get total_output_tokens)

[ -n "$cwd" ] && [ "$cwd" != null ] && [ -d "$cwd" ] && cd "$cwd" 2>/dev/null || true

bold=$(printf '\033[1m');    reset=$(printf '\033[0m')
cyan=$(printf '\033[36m');   green=$(printf '\033[32m')
yellow=$(printf '\033[33m'); red=$(printf '\033[31m')
magenta=$(printf '\033[35m'); blue=$(printf '\033[34m')
dim=$(printf '\033[2m')

parts=''
add() { parts="${parts:+$parts ${dim}|${reset} }$1"; }

[ -n "$model" ] && [ "$model" != null ] && add "${bold}${cyan}${model}${reset}"

if [ -n "$cwd" ] && [ "$cwd" != null ]; then
  add "${green}${cwd##*/}${reset}"
  add "${yellow}${cwd}${reset}"
fi

if [ -n "$pct" ] && [ "$pct" != null ]; then
  pct_i=$(printf '%.0f' "$pct" 2>/dev/null) || pct_i=$pct
  cc=$green
  [ "$pct_i" -ge 50 ] && cc=$yellow
  [ "$pct_i" -ge 80 ] && cc=$red
  add "${cc}ctx:${pct_i}%${reset}"
fi

if [ -n "$tin" ] && [ "$tin" != null ] && [ -n "$tout" ] && [ "$tout" != null ]; then
  add "${magenta}tokens:$((tin + tout))${reset}"
fi

d=$(pact_dir 2>/dev/null || true)
if [ -n "$d" ]; then
  root=$(pact_project_root)
  proj="${root##*/}"
  flow=$(pact_toml_get_in "$d/config.toml" mode flow 2>/dev/null || true)
  case "$flow" in
    full) mcolor=$yellow ;;
    lite) mcolor=$blue ;;
    *)    mcolor=$dim ;;
  esac

  pact_seg="${bold}${cyan}PACT${reset}"
  [ -n "$flow" ] && [ "$flow" != null ] && pact_seg="$pact_seg ${mcolor}[${flow}]${reset}"
  pact_seg="$pact_seg ${bold}${proj}${reset}"

  spec=$(sh "$dir/status.sh" --oneline 2>/dev/null || true)
  spec="${spec#PACT }"
  [ -n "$spec" ] && pact_seg="$pact_seg ${dim}·${reset} $spec"

  add "$pact_seg"
fi

printf '%s\n' "$parts"
