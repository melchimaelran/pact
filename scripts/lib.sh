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

# Read `key = value` from inside a `[section]` of a .pact/*.toml file. Handles the
# nested keys `pact_toml_get` (flat only) misses. Usage: pact_toml_get_in <file> <section> <key>
pact_toml_get_in() {
  _f=$1; _s=$2; _k=$3
  [ -f "$_f" ] || return 1
  awk -v s="[$_s]" -v k="$_k" '
    $0 == s { ins=1; next }
    /^[[:space:]]*\[/ { ins=0 }
    ins && match($0, "^[[:space:]]*" k "[[:space:]]*=[[:space:]]*") {
      v = substr($0, RLENGTH + 1)
      sub(/[[:space:]]*#.*$/, "", v)
      sub(/^"/, "", v); sub(/"$/, "", v)
      sub(/^'"'"'/, "", v); sub(/'"'"'$/, "", v)
      sub(/[[:space:]]+$/, "", v)
      print v; exit
    }
  ' "$_f"
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

# Read one key from a markdown file's YAML frontmatter (the block between the
# first two `---` lines). Usage: fm_get <file> <key>. Strips quotes and inline
# `# comments`. Prints nothing if absent.
fm_get() {
  _f=$1; _k=$2
  [ -f "$_f" ] || return 0
  awk -v k="$_k" '
    NR==1 && $0=="---" {infm=1; next}
    infm && $0=="---" {exit}
    infm {
      line=$0
      if (match(line, "^[[:space:]]*" k "[[:space:]]*:[[:space:]]*")) {
        v=substr(line, RLENGTH+1)
        sub(/[[:space:]]*#.*$/, "", v)
        sub(/^"/, "", v); sub(/"$/, "", v)
        sub(/^'"'"'/, "", v); sub(/'"'"'$/, "", v)
        sub(/[[:space:]]+$/, "", v)
        print v
        exit
      }
    }
  ' "$_f"
}

# Like fm_get, but for a YAML block scalar (`key: >-` / `key: |`). Returns the
# indented continuation lines joined with single spaces. Also handles the plain
# `key: value` form. Stops at the closing `---`, a blank line, or a line that is
# not more-indented than the key. Usage: fm_get_block <file> <key>
fm_get_block() {
  _f=$1; _k=$2
  [ -f "$_f" ] || return 0
  awk -v k="$_k" '
    NR==1 && $0=="---" {infm=1; next}
    infm && $0=="---" {exit}
    !infm {next}
    !inblock {
      if (match($0, "^[[:space:]]*" k "[[:space:]]*:[[:space:]]*[|>][+-]?[[:space:]]*$")) {
        inblock=1; next
      }
      if (match($0, "^[[:space:]]*" k "[[:space:]]*:[[:space:]]*")) {
        v=substr($0, RLENGTH+1)
        sub(/[[:space:]]*#.*$/, "", v)
        sub(/^"/, "", v); sub(/"$/, "", v)
        sub(/^'"'"'/, "", v); sub(/'"'"'$/, "", v)
        sub(/[[:space:]]+$/, "", v)
        print v
        exit
      }
      next
    }
    inblock {
      if ($0 !~ /^[[:space:]]/ || $0 ~ /^[[:space:]]*$/) exit
      line=$0
      sub(/^[[:space:]]+/, "", line)
      sub(/[[:space:]]+$/, "", line)
      out = (out == "" ? line : out " " line)
    }
    END { if (out != "") print out }
  ' "$_f"
}
