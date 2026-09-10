#!/bin/sh
# pact gitignore          -> ensure the managed PACT block in the project .gitignore
# pact gitignore --check  -> exit 1 if the block is missing or .pact/ is ignored wholesale
set -eu
. "$(dirname "$0")/lib.sh"

root=$(pact_project_root) || pact_die "not in a git repo"
gi="$root/.gitignore"

BEGIN='# --- PACT (managed) ---'
END='# --- end PACT ---'
BLOCK="$BEGIN
.pact/wave.lock
.pact/cache/
.pact/tmp/
pact-wt/
$END"

if [ "${1:-}" = "--check" ]; then
  [ -f "$gi" ] || { echo "missing: no .gitignore"; exit 1; }
  grep -qF "$BEGIN" "$gi" || { echo "missing: PACT managed block"; exit 1; }
  if grep -Eq '^[[:space:]]*\.pact/?[[:space:]]*$' "$gi"; then
    echo "error: .pact/ is ignored wholesale — that breaks sharing"; exit 1
  fi
  echo "ok"; exit 0
fi

touch "$gi"
if grep -qF "$BEGIN" "$gi"; then
  # replace the existing managed block
  tmp=$(mktemp)
  awk -v b="$BEGIN" -v e="$END" '
    $0==b {skip=1; print; next}
    $0==e {skip=0; next}
    skip {next}
    {print}
  ' "$gi" > "$tmp"
  # re-insert the fresh body right after BEGIN
  awk -v b="$BEGIN" '
    {print}
    $0==b {
      print ".pact/wave.lock"; print ".pact/cache/"; print ".pact/tmp/"; print "pact-wt/"; print "# --- end PACT ---"
    }
  ' "$tmp" > "$gi"
  rm -f "$tmp"
else
  [ -s "$gi" ] && printf '\n' >> "$gi"
  printf '%s\n' "$BLOCK" >> "$gi"
fi
echo "ok"
