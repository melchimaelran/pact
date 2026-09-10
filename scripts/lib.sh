#!/bin/sh
# Shared helpers for PACT scripts. Source this: . "$(dirname "$0")/lib.sh"
# POSIX sh only. No bashisms.

# Repo root of the *user's project* (not the plugin). Empty if not in a git repo.
pact_project_root() {
  git rev-parse --show-toplevel 2>/dev/null || true
}

# Path to the project's .pact directory, or empty if there is none.
pact_dir() {
  root=$(pact_project_root)
  [ -n "$root" ] && [ -d "$root/.pact" ] && printf '%s\n' "$root/.pact"
}

# True (exit 0) when the current directory is inside a PACT project.
is_pact_project() {
  [ -n "$(pact_dir)" ]
}

# Read a top-level `key = value` from a .pact/*.toml file. Naive but sufficient
# for the flat keys PACT writes. Usage: pact_toml_get <file> <key>
pact_toml_get() {
  _f=$1; _k=$2
  [ -f "$_f" ] || return 1
  sed -n "s/^[[:space:]]*${_k}[[:space:]]*=[[:space:]]*//p" "$_f" \
    | head -n1 \
    | sed 's/^"//; s/"$//; s/[[:space:]]*#.*$//; s/[[:space:]]*$//'
}

# The project's declared .pact schema number (default 0 when unset/absent).
pact_schema() {
  d=$(pact_dir) || { echo 0; return; }
  v=$(pact_toml_get "$d/config.toml" schema 2>/dev/null || true)
  [ -n "$v" ] && printf '%s\n' "$v" || echo 0
}

# The schema this plugin build supports.
PACT_SUPPORTED_SCHEMA=1
export PACT_SUPPORTED_SCHEMA

# Gate: exit 3 with a message if the project schema != supported.
pact_schema_gate() {
  have=$(pact_schema)
  if [ "$have" != "$PACT_SUPPORTED_SCHEMA" ]; then
    echo "pact: .pact schema $have, plugin supports $PACT_SUPPORTED_SCHEMA — run /pact:migrate" >&2
    exit 3
  fi
}

pact_die() { echo "pact: $*" >&2; exit 1; }
