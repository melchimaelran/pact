#!/bin/sh
# PreToolUse guard registered by ship / build / fix / spec while they run.
# Blocks a Bash command that would write an AI-authorship trailer or footer into
# a commit, PR, issue, or branch. Matches the trailer *forms* only, so a commit
# that legitimately discusses Claude Code is untouched.
#
# Reads the tool call as JSON on stdin: { tool_input: { command: "..." } }.
# Exit 0 = allow. Exit 2 = block (stderr is shown to the model).
set -eu

payload=$(cat)
cmd=$(printf '%s' "$payload" | sed -n 's/.*"command"[[:space:]]*:[[:space:]]*"\(.*\)".*/\1/p')
[ -n "$cmd" ] || exit 0

case "$cmd" in
  *git*commit*|*gh\ pr*|*gh\ issue*|*git*branch*|*git*push*) : ;;
  *) exit 0 ;;
esac

# Forbidden forms (case-insensitive).
low=$(printf '%s' "$cmd" | tr '[:upper:]' '[:lower:]')
for pat in \
  'co-authored-by:.*claude' \
  'co-authored-by:.*anthropic' \
  'co-authored-by:.*noreply@anthropic' \
  'generated with .*claude' \
  'generated with .*\[claude code\]' \
  '🤖 generated' \
  'claude-session:' \
  'this commit was.*by.*claude'
do
  if printf '%s' "$low" | grep -Eiq "$pat"; then
    echo "no-ai-guard: this command carries an AI-authorship trailer/footer ('$pat'). PACT repos must have none. Remove it and retry." >&2
    exit 2
  fi
done

exit 0
