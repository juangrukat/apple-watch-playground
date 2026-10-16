#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
swift build -c release
.build/release/WatchPlayground --self-test
TEST_BUILD="$(mktemp -d "${TMPDIR:-/tmp}/watch-playground-check.XXXXXX")"
trap 'rm -rf "$TEST_BUILD"' EXIT
MAC=Sources/WatchPlayground
WATCH=WatchCompanion
CORE=("$MAC/Model.swift" "$MAC/BluetoothLink.swift" "$MAC/BLEWire.swift" "$MAC/CommandWire.swift" "$MAC/RuntimeMetrics.swift" "$MAC/PoseMath.swift" "$MAC/CardModels.swift")
for check in CardRedesignCheck PoseLocationCheck; do
  swiftc -parse-as-library "${CORE[@]}" "Verification/$check.swift" -o "$TEST_BUILD/$check"
  WATCHPLAYGROUND_WORKSPACE_DIRECTORY="$TEST_BUILD/$check-workspaces" "$TEST_BUILD/$check" --self-test
done
swiftc -parse-as-library "$WATCH/SessionCore.swift" "$WATCH/PacketScheduler.swift" "$MAC/BLEWire.swift" "$MAC/CommandWire.swift" "$MAC/RuntimeMetrics.swift" "$MAC/LatestFeedQueue.swift" Verification/WatchRewriteCheck.swift -o "$TEST_BUILD/watch"
"$TEST_BUILD/watch"
swiftc -parse-as-library "$MAC/PoseMath.swift" "$MAC/BLEWire.swift" "$MAC/RuntimeMetrics.swift" Verification/DiagnosticsCheck.swift -o "$TEST_BUILD/diagnostics"
"$TEST_BUILD/diagnostics"
swiftc -parse-as-library "$WATCH/AudioMeter.swift" Verification/AudioMeterCheck.swift -o "$TEST_BUILD/audio"
"$TEST_BUILD/audio"
swiftc -parse-as-library "$MAC/BLEWire.swift" "$MAC/LatestFeedQueue.swift" Verification/BLEWireCheck.swift -o "$TEST_BUILD/wire"
"$TEST_BUILD/wire"
