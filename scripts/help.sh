#!/bin/sh
# pact help              -> the PACT command map, grouped by place in the flow
# pact help <command>    -> one command's syntax and full description
# pact help --list       -> command names, one per line
# Read-only. Zero model tokens. Does not gate on schema.
set -eu
. "$(dirname "$0")/lib.sh"

PACT_ROOT=${PACT_ROOT:-$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)}
SKILLS="$PACT_ROOT/skills"

# Ordered groups. The command set is otherwise fixed; per-command text is read
# live from each skill's SKILL.md so it can never drift. Invariant: the three
# lists together must name every skills/<name>/ directory —
#   diff <(pact help --list | sort) <(ls skills | sort)   # must be empty
PIPELINE="init spec plan build ship"
LAYERS="design team review"
ANYTIME="fix security status check config adr migrate help"

version=$(sed -n 's/.*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' \
  "$PACT_ROOT/.claude-plugin/plugin.json" 2>/dev/null | head -n1)
[ -n "$version" ] || version="?"

# unescape \" -> " (argument-hint values carry escaped quotes)
unesc() { sed 's/\\"/"/g'; }

# emit <name> -> the invocation line, then the skill's description wrapped and
# indented. argument-hint and description are read live from the SKILL.md.
emit() {
  _f="$SKILLS/$1/SKILL.md"
  [ -f "$_f" ] || return 0
  _h=$(fm_get "$_f" argument-hint | unesc)
  [ -n "$_h" ] && _h=" $_h"
  printf '  /pact:%s%s\n' "$1" "$_h"
  fm_get_block "$_f" description | fold -s -w 74 | sed -e "s/ *$//" -e "s/^/      /"
}

case "${1:-}" in
  --list)
    # shellcheck disable=SC2086
    printf '%s\n' $PIPELINE $LAYERS $ANYTIME
    exit 0
    ;;
  "")
    : # fall through to the overview
    ;;
  -*)
    echo "usage: pact help [<command>|--list]" >&2
    exit 2
    ;;
  *)
    name=$1
    if [ ! -f "$SKILLS/$name/SKILL.md" ]; then
      echo "pact: no such command '$name'" >&2
      # shellcheck disable=SC2086
      echo "commands: $PIPELINE $LAYERS $ANYTIME" >&2
      exit 2
    fi
    hint=$(fm_get "$SKILLS/$name/SKILL.md" argument-hint | unesc)
    [ -n "$hint" ] && hint=" $hint"
    printf '/pact:%s%s\n\n' "$name" "$hint"
    fm_get_block "$SKILLS/$name/SKILL.md" description | fold -s -w 78 | sed "s/ *$//"
    echo
    echo "full detail: docs/COMMANDS.md"
    exit 0
    ;;
esac

# --- overview ---------------------------------------------------------------
echo "PACT v$version — Pragmatic, Agent-Controlled, Terminal-based"
echo "spec -> plan -> build -> ship. TDD, dependency-ordered parallel waves, Decision Records."
echo
# shellcheck disable=SC2086  # deliberate word-split of the space-separated lists
echo "THE PIPELINE"
for c in $PIPELINE; do emit "$c"; done
echo
echo "OPTIONAL LAYERS  (full mode — enable with /pact:config)"
for c in $LAYERS; do emit "$c"; done
echo
echo "ANYTIME"
for c in $ANYTIME; do emit "$c"; done
echo
echo "/pact:help <command>   syntax and full description for one command"
echo "docs: docs/COMMANDS.md (every flag) · docs/CONFIG.md (settings) · README.md"

if ! is_pact_project; then
  echo
  echo "No .pact/ here — run /pact:init to set PACT up in this project."
fi
