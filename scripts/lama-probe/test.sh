#!/usr/bin/env bash
set -euo pipefail
TASK_SCREEN="${1:-ipad}"
mkdir -p build
xcrun simctl list devices available -j > .work/lama-probe-devices.json
TASK_DEVICE=$(python3 - "$TASK_SCREEN" <<'PY'
import json,sys
prefix='iPad' if sys.argv[1]=='ipad' else 'iPhone'
d=json.load(open('.work/lama-probe-devices.json'))['devices']
for runtime,devices in sorted(d.items(),reverse=True):
 if 'iOS' not in runtime:continue
 matches=[v for v in devices if v['name'].startswith(prefix) and v['isAvailable']]
 if matches:print(matches[0]['udid']);break
else:raise RuntimeError('No matching iOS simulator')
PY
)
xcrun simctl boot "$TASK_DEVICE" || true
xcrun simctl bootstatus "$TASK_DEVICE" -b
TASK_STATUS=0
xcodebuild -project scripts/lama-probe/LaMaProbe.xcodeproj -scheme LaMaProbe -configuration Debug -destination "platform=iOS Simulator,id=$TASK_DEVICE" -parallel-testing-enabled NO -test-timeouts-enabled YES -maximum-test-execution-time-allowance 1200 -derivedDataPath .work/lama-probe-build -resultBundlePath "build/lama-probe-$TASK_SCREEN.xcresult" ARCHS=x86_64 ONLY_ACTIVE_ARCH=YES test > "build/lama-probe-$TASK_SCREEN.log" 2>&1 || TASK_STATUS=$?
rg -n 'error:|Test Case .* (passed|failed)|BIG_LAMA|Executed .* failures' "build/lama-probe-$TASK_SCREEN.log" | tail -50 || true
if [[ -d "build/lama-probe-$TASK_SCREEN.xcresult" ]]; then
 xcrun xcresulttool export attachments --path "build/lama-probe-$TASK_SCREEN.xcresult" --output-path "build/lama-probe-attachments/$TASK_SCREEN" || true
fi
exit "$TASK_STATUS"
