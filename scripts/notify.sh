#!/bin/sh
# pact notify <event>   -> play a short sound so the user can step away.
#
# Events:   done   a turn / task finished (Stop hook)
#           wait   PACT needs input — permission prompt or idle (Notification hook)
#           wave   a build wave settled (called from skills/build)
#           fail   an escalation — QA loop exhausted, unresolvable conflict,
#                  review NEEDS_FIXES, verification gate failed
#
# Wired to the Stop and Notification hooks (hooks/hooks.json); build and review
# call `pact notify wave|fail` directly. Zero model tokens. Config-gated.
# Backgrounded and fully silent — it never writes output and always exits 0, so
# it cannot fail a hook or a tool call.
#
# Gate:   env PACT_NOTIFY=off  hard-disables it anywhere.
#         [notify].sound  in .pact/config.toml:
#             off        (default) nothing
#             attention  only `wait` and `fail`
#             all        every event
#         [notify].method  auto | bell | command
#         [notify].command a shell line for method=command; {event} is substituted
set -eu
. "$(dirname "$0")/lib.sh"

event=${1:-}
case "$event" in done|wait|wave|fail) : ;; *) exit 0 ;; esac

[ "${PACT_NOTIFY:-}" = "off" ] && exit 0

d=$(pact_dir) || exit 0                       # not a PACT project -> silent
cfg="$d/config.toml"

sound=$(pact_toml_get_in "$cfg" notify sound 2>/dev/null || true)
[ -n "$sound" ] || sound=off
case "$sound" in
  off)       exit 0 ;;
  attention) case "$event" in wait|fail) : ;; *) exit 0 ;; esac ;;
  all)       : ;;
  *)         exit 0 ;;
esac

method=$(pact_toml_get_in "$cfg" notify method 2>/dev/null || true)
[ -n "$method" ] || method=auto

# --- play, detached, output discarded ------------------------------------------
play() { ( "$@" >/dev/null 2>&1 & ) ; }

bell() {
  # n short terminal bells, spaced. Works wherever the bell is not muted.
  # Detached so the spacing sleeps never delay the hook.
  _n=$1
  ( i=0
    while [ "$i" -lt "$_n" ]; do
      printf '\a'
      i=$((i + 1))
      [ "$i" -lt "$_n" ] && sleep 0.18
    done ) 2>/dev/null &
}

# a system sound file for this event, or "" if none found. Tries several names
# per event because packaged sound themes are not consistent.
sysfile() {
  _fdo=/usr/share/sounds/freedesktop/stereo
  _mac=/System/Library/Sounds
  case "$event" in
    done) _c="$_fdo/complete.oga $_fdo/bell.oga $_mac/Glass.aiff" ;;
    wave) _c="$_fdo/message.oga $_fdo/message-new-instant.oga $_fdo/bell.oga $_mac/Tink.aiff" ;;
    wait) _c="$_fdo/dialog-question.oga $_fdo/dialog-information.oga $_fdo/message.oga $_fdo/bell.oga $_mac/Ping.aiff $_mac/Funk.aiff" ;;
    fail) _c="$_fdo/dialog-error.oga $_fdo/dialog-warning.oga $_fdo/suspend-error.oga $_mac/Sosumi.aiff $_mac/Basso.aiff" ;;
  esac
  # shellcheck disable=SC2086  # deliberate split of the candidate list
  for _p in $_c; do
    [ -r "$_p" ] && { printf '%s\n' "$_p"; return; }
  done
}

beats() { case "$event" in done) echo 1 ;; wave) echo 2 ;; wait) echo 3 ;; fail) echo 4 ;; esac ; }

run_command() {
  _c=$(pact_toml_get_in "$cfg" notify command 2>/dev/null || true)
  [ -n "$_c" ] || return 1
  _c=$(printf '%s' "$_c" | sed "s/{event}/$event/g")
  ( sh -c "$_c" >/dev/null 2>&1 & )
}

case "$method" in
  command) run_command || true ;;
  bell)    bell "$(beats)" ;;
  auto|*)
    f=$(sysfile)
    if [ -n "$f" ] && command -v afplay  >/dev/null 2>&1; then play afplay "$f"
    elif [ -n "$f" ] && command -v paplay >/dev/null 2>&1; then play paplay "$f"
    elif [ -n "$f" ] && command -v pw-play >/dev/null 2>&1; then play pw-play "$f"
    elif [ -n "$f" ] && command -v aplay  >/dev/null 2>&1; then play aplay -q "$f"
    else bell "$(beats)"
    fi
    ;;
esac

exit 0
