#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p build/screenshots
xcrun simctl list devices available -j > .work/devices.json
python3 - <<'PY'
import json,pathlib
items=[x for a in json.load(open('.work/devices.json'))['devices'].values() for x in a if x['isAvailable'] and 'iPhone' in x['name']]
small=next((x for x in items if 'SE' in x['name']),None)
modern=next((x for x in items if '16 Pro' in x['name']),items[0])
if small is None: raise SystemExit('iPhone SE simulator required to verify small-screen layout; do not silently omit this check')
pathlib.Path('.work/simulators.txt').write_text('\n'.join(x['udid'] for x in [small,modern]))
PY
TASK_INDEX=0
while IFS= read -r TASK_DEVICE || [[ -n "$TASK_DEVICE" ]]; do
  TASK_INDEX=$((TASK_INDEX+1))
  TASK_STATUS=0
  xcodebuild -project CookiesEditor.xcodeproj -scheme CookiesOffline -configuration Debug -destination "platform=iOS Simulator,id=$TASK_DEVICE" -derivedDataPath .work/simulator -resultBundlePath "build/iPhone-$TASK_INDEX.xcresult" ARCHS=x86_64 ONLY_ACTIVE_ARCH=YES test > "build/test-$TASK_INDEX.log" 2>&1 || TASK_STATUS=$?
  xcrun xcresulttool export attachments --path "build/iPhone-$TASK_INDEX.xcresult" --output-path "build/screenshots/iPhone-$TASK_INDEX"
  xcrun simctl shutdown "$TASK_DEVICE" || true
  if [[ "$TASK_STATUS" != 0 ]]; then tail -100 "build/test-$TASK_INDEX.log"; exit "$TASK_STATUS"; fi
done < .work/simulators.txt
