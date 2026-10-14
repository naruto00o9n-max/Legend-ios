#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
TASK_SCREEN="${1:-ipad}"
mkdir -p .work build
# The standalone suite also runs independently, not only after a connected test.
if [[ ! -s .work/simulator-id ]]; then
  xcrun simctl list devices available -j > .work/local-devices.json
  python3 - "$TASK_SCREEN" <<'PYDEVICE'
import json,pathlib,sys
kind='iPad' if sys.argv[1]=='ipad' else 'iPhone'
items=[d for ds in json.load(open('.work/local-devices.json'))['devices'].values() for d in ds if d['isAvailable'] and kind in d['name']]
if not items:raise RuntimeError('No matching simulator')
device=next((d for d in items if ('11-inch' if kind=='iPad' else '16 Pro') in d['name']),items[0])
pathlib.Path('.work/simulator-id').write_text(device['udid'])
print(device['name'],device['udid'])
PYDEVICE
fi
TASK_DEVICE=$(cat .work/simulator-id)
xcrun simctl boot "$TASK_DEVICE" || true
xcrun simctl bootstatus "$TASK_DEVICE" -b
open -a Simulator --args -CurrentDeviceUDID "$TASK_DEVICE"
# Seed this suite explicitly, even if a preceding connected UI run failed.
python3 - <<'PYPHOTO'
import pathlib,struct,zlib
p=pathlib.Path('.work/Photos-800x15000.png')
if not p.exists():
 w,h=800,15000
 chunk=lambda n,d:struct.pack('>I',len(d))+n+d+struct.pack('>I',zlib.crc32(n+d)&0xffffffff)
 rows=b''.join(b'\0'+bytes((240-y%40,)*3)*w for y in range(h))
 p.write_bytes(b'\x89PNG\r\n\x1a\n'+chunk(b'IHDR',struct.pack('>IIBBBBB',w,h,8,2,0,0,0))+chunk(b'IDAT',zlib.compress(rows))+chunk(b'IEND',b''))
PYPHOTO
xcrun simctl addmedia "$TASK_DEVICE" .work/Photos-800x15000.png
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
