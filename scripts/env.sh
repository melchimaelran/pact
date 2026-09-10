#!/bin/sh
# pact env <key> [--path F] [--wt NAME] [--port N] [--db URL] [--print]
#
# Resolve a command from stack.toml [env] and run it under the project's
# isolation strategy. <key> is one of: setup test test_one lint typecheck build
# dev format.
#
#   {path} in the command is replaced by --path.
#   inline-env  : PORT / DATABASE_URL are prefixed when --port / --db are given.
#   docker-compose : the command is wrapped in `docker compose -p pact_<wt> run`.
#   serialize / auto : run as-is.
#
# --print emits the resolved command instead of running it. Exit code is the
# command's own.
set -eu
. "$(dirname "$0")/lib.sh"

root=$(pact_project_root) || pact_die "not in a git repo"
d=$(pact_dir) || pact_die "not a PACT project"
stack="$d/stack.toml"

key=${1:-}; [ -n "$key" ] || pact_die "usage: pact env <key> [opts]"
shift
path=''; wt=''; port=''; db=''; printonly=0
while [ $# -gt 0 ]; do
  case "$1" in
    --path) path=$2; shift 2 ;;
    --wt)   wt=$2;   shift 2 ;;
    --port) port=$2; shift 2 ;;
    --db)   db=$2;   shift 2 ;;
    --print) printonly=1; shift ;;
    *) pact_die "unknown arg: $1" ;;
  esac
done

cmd=$(pact_toml_get "$stack" "$key" || true)
[ -n "$cmd" ] || { [ "$printonly" = 1 ] && exit 0; echo "pact env: [$key] is empty — skipped" >&2; exit 0; }

case "$cmd" in
  *'{path}'*) [ -n "$path" ] || pact_die "[$key] needs {path} but --path was not given"
             cmd=$(printf '%s' "$cmd" | sed "s#{path}#$path#g") ;;
esac

iso=$(pact_toml_get "$stack" isolation || echo auto)
prefix=''
case "$iso" in
  inline-env)
    [ -n "$port" ] && prefix="PORT=$port "
    [ -n "$db" ]   && prefix="${prefix}DATABASE_URL=$db "
    ;;
  docker-compose)
    if [ -n "$wt" ]; then
      svc=$(pact_toml_get "$stack" compose_service || echo app)
      cmd="docker compose -p pact_$wt run --rm $svc sh -lc '$cmd'"
    fi
    ;;
esac

full="${prefix}${cmd}"
if [ "$printonly" = 1 ]; then
  printf '%s\n' "$full"
  exit 0
fi

( cd "$root" && sh -c "$full" )
