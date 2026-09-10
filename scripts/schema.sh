#!/bin/sh
# pact schema            -> print the project's .pact schema (0 if none)
# pact schema --gate     -> exit 3 with a message when it != the supported schema
# pact schema --supported-> print the schema this plugin build supports
set -eu
. "$(dirname "$0")/lib.sh"

case "${1:-}" in
  --supported) printf '%s\n' "$PACT_SUPPORTED_SCHEMA" ;;
  --gate)      pact_schema_gate; echo "ok" ;;
  ""|--print)  pact_schema ;;
  *)           echo "usage: pact schema [--print|--gate|--supported]" >&2; exit 2 ;;
esac
