#!/bin/bash
# Record the tvOS simulator with a hard duration cap.
#
# Bare `xcrun simctl io <device> recordVideo` has no time limit: an interrupted
# or forgotten recording keeps growing (a 2026-10-31 cleanup found a single
# 19.9GB orphan in /private/tmp). Every recording started for Doki evidence must
# go through this wrapper: it writes inside the gitignored .local/artifacts tree,
# always stops, and reports the result size.
#
# Usage:
#   tv-record.sh <task-id> <name> [max-seconds]
#
# Examples:
#   scripts/tv-record.sh FOCUS-002 focus-motion 45
#   DOKI_TV_DEVICE=<udid> scripts/tv-record.sh REWORK-008 shelf 90
#
# Arguments:
#   task-id      artifact folder under .local/artifacts/ (e.g. FOCUS-002)
#   name         output file stem; written as <name>.mp4
#   max-seconds  hard cap, default 60, clamped to 1..600
set -uo pipefail

TASK="${1:-}"
NAME="${2:-}"
CAP="${3:-60}"

if [ -z "$TASK" ] || [ -z "$NAME" ]; then
  echo "usage: tv-record.sh <task-id> <name> [max-seconds]" >&2
  exit 2
fi

case "$CAP" in
  ''|*[!0-9]*) echo "max-seconds must be a whole number, got: $CAP" >&2; exit 2 ;;
esac
[ "$CAP" -lt 1 ] && CAP=1
if [ "$CAP" -gt 600 ]; then
  echo "note: clamping max-seconds $CAP to 600"
  CAP=600
fi

# Evidence never belongs in a world-writable temp directory.
case "$TASK$NAME" in
  *private/tmp*|*/tmp/*|*..*) echo "refusing: keep artifacts under .local/artifacts" >&2; exit 2 ;;
esac

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEVICE="${DOKI_TV_DEVICE:-A3FD875C-F0DC-4BCE-880D-C4F6680D3C97}"
OUT_DIR="$ROOT/.local/artifacts/$TASK"
FILE="$OUT_DIR/$NAME.mp4"

mkdir -p "$OUT_DIR"
# Re-check after creation so a symlinked task directory cannot escape .local.
RESOLVED="$(cd "$OUT_DIR" && pwd -P)"
case "$RESOLVED" in
  "$ROOT"/.local/artifacts/*) ;;
  *) echo "refusing: $RESOLVED is outside .local/artifacts" >&2; exit 2 ;;
esac

if ! xcrun simctl list devices 2>/dev/null | grep -q "$DEVICE"; then
  echo "device $DEVICE not found; set DOKI_TV_DEVICE" >&2
  exit 1
fi

echo "recording $DEVICE -> ${FILE#$ROOT/} (cap ${CAP}s)"
[ -e "$FILE" ] && echo "  (replacing existing file)"

REC_PID=""
WATCH_PID=""

stop_recording() {
  if [ -n "$REC_PID" ]; then
    kill -INT "$REC_PID" 2>/dev/null
  fi
}
cleanup() {
  stop_recording
  [ -n "$WATCH_PID" ] && kill "$WATCH_PID" 2>/dev/null
}
trap 'echo; echo "interrupted, stopping recording"; cleanup; wait 2>/dev/null; exit 130' INT TERM

xcrun simctl io "$DEVICE" recordVideo --codec=h264 --force "$FILE" &
REC_PID=$!

# Watchdog: stop the recording when the cap is reached, even if nobody is watching.
(
  sleep "$CAP"
  if kill -INT "$REC_PID" 2>/dev/null; then
    echo "  reached ${CAP}s cap, stopping"
  fi
) &
WATCH_PID=$!

wait "$REC_PID" 2>/dev/null
REC_STATUS=$?

kill "$WATCH_PID" 2>/dev/null
wait "$WATCH_PID" 2>/dev/null
REC_PID=""
trap - INT TERM

if [ ! -s "$FILE" ]; then
  echo "recording produced no data (exit $REC_STATUS)" >&2
  exit 1
fi

SIZE_KB=$(du -sk "$FILE" 2>/dev/null | cut -f1)
SIZE_KB=${SIZE_KB:-0}
echo "done: $(du -h "$FILE" | cut -f1) at ${FILE#$ROOT/}"

if [ "$SIZE_KB" -gt 524288 ]; then
  echo "warning: clip is over 500MB; shorten the capture or drop a frame sequence instead"
fi

echo "hint: scripts/local-cleanup.sh --check keeps .local/artifacts bounded"
