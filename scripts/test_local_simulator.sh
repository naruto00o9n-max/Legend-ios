#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
TASK_SCREEN="${1:-ipad}"
TASK_DEVICE=$(cat .work/simulator-id)
xcrun simctl boot "$TASK_DEVICE" || true
xcrun simctl bootstatus "$TASK_DEVICE" -b
open -a Simulator --args -CurrentDeviceUDID "$TASK_DEVICE"
TASK_STATUS=0
xcodebuild -project CookiesEditor.xcodeproj -scheme CookiesLocal -configuration Debug -destination "platform=iOS Simulator,id=$TASK_DEVICE" -parallel-testing-enabled NO -derivedDataPath .work/simulator-local -resultBundlePath "build/$TASK_SCREEN-local.xcresult" -only-testing:CookiesLocalUITests ARCHS=x86_64 ONLY_ACTIVE_ARCH=YES test > "build/test-$TASK_SCREEN-local.log" 2>&1 || TASK_STATUS=$?
if [[ "$TASK_STATUS" == 0 ]]; then
  xcodebuild -project CookiesEditor.xcodeproj -scheme CookiesLocal -configuration Debug -destination "platform=iOS Simulator,id=$TASK_DEVICE" -parallel-testing-enabled NO -derivedDataPath .work/simulator-local -resultBundlePath "build/$TASK_SCREEN-local-photos.xcresult" -only-testing:CookiesLocalUITests/LocalEditionUITests/testLocalPhotosEditingAndOriginalSizeExport ARCHS=x86_64 ONLY_ACTIVE_ARCH=YES test-without-building > "build/test-$TASK_SCREEN-local-photos.log" 2>&1 || TASK_STATUS=$?
fi
if [[ "$TASK_STATUS" == 0 ]]; then
  TASK_CONTAINER=$(xcrun simctl get_app_container "$TASK_DEVICE" com.cookies.editor.local data)
  python3 scripts/verify_photos_import.py "$TASK_CONTAINER/Documents/Cookies" "build/photos-integrity-$TASK_SCREEN-local.json" || TASK_STATUS=$?
fi
rg -n "\.swift:[0-9]+: error:|Test Case .* failed|Executed .* failures" "build/test-$TASK_SCREEN-local.log" | tail -35 || true
xcrun xcresulttool export attachments --path "build/$TASK_SCREEN-local.xcresult" --output-path "build/screenshots/$TASK_SCREEN-local" || true
python3 - "$TASK_SCREEN" "$TASK_STATUS" <<'PY'
import json,pathlib,sys
screen,status=sys.argv[1:]
pathlib.Path('build/gates-'+screen+'-local.json').write_text(json.dumps({'local_edition_ui_and_source_integrity_exit_code':int(status)},indent=2)+'\n')
PY
xcrun simctl shutdown "$TASK_DEVICE" || true
exit "$TASK_STATUS"
