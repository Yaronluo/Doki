#!/bin/bash
# Start one tvOS UI test, capture simulator frames while it holds a screen, then
# stop the test. This avoids relying on XCUITest attachment finalization, which
# can hang after tvOS tests in this toolchain.
set -uo pipefail

TEST="${1:?usage: run-ui-tour.sh <test-identifier> <output-dir> [delay] [frames] [interval]}"
OUT="${2:?usage: run-ui-tour.sh <test-identifier> <output-dir> [delay] [frames] [interval]}"
DELAY="${3:-12}"
FRAMES="${4:-35}"
INTERVAL="${5:-2}"
DEVICE="${DOKI_TV_DEVICE:-A3FD875C-F0DC-4BCE-880D-C4F6680D3C97}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
mkdir -p "$OUT"

cd "$ROOT"
xcodebuild test \
  -project Doki.xcodeproj \
  -scheme DokiTV \
  -destination "platform=tvOS Simulator,id=$DEVICE" \
  -derivedDataPath .local/DerivedData/UITests \
  CODE_SIGNING_ALLOWED=NO \
  -only-testing:"$TEST" > "$OUT/test.log" 2>&1 &
TEST_PID=$!

sleep "$DELAY"
for i in $(seq -w 1 "$FRAMES"); do
  TS="$(date +%H%M%S)"
  xcrun simctl io "$DEVICE" screenshot "$OUT/${i}-${TS}.png" >/dev/null 2>&1 || true
  sleep "$INTERVAL"
done

kill -INT "$TEST_PID" 2>/dev/null || true
sleep 1
kill -TERM "$TEST_PID" 2>/dev/null || true
xcrun simctl terminate "$DEVICE" com.doki.tv >/dev/null 2>&1 || true
echo "captured $FRAMES frames to $OUT"
