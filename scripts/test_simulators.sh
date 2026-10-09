#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
TASK_SCREEN="${1:-ipad}"
mkdir -p build/screenshots .work
xcrun simctl list devices available -j > .work/devices.json
python3 - "$TASK_SCREEN" <<'PYDEV'
import json,pathlib,sys
items=[x for a in json.load(open('.work/devices.json'))['devices'].values() for x in a if x['isAvailable']]
kind='iPad' if sys.argv[1]=='ipad' else 'iPhone'
matching=[x for x in items if kind in x['name']]
if not matching:raise SystemExit('Required '+kind+' simulator missing')
device=next((x for x in matching if ('11-inch' if kind=='iPad' else '16 Pro') in x['name']),matching[0])
pathlib.Path('.work/simulator-id').write_text(device['udid'])
print(device['name'],device['udid'])
PYDEV
TASK_DEVICE=$(cat .work/simulator-id)
xcrun simctl boot "$TASK_DEVICE" || true
xcrun simctl bootstatus "$TASK_DEVICE" -b
open -a Simulator --args -CurrentDeviceUDID "$TASK_DEVICE"
# Seed the actual Photos library; the picker test must import this asset.
python3 - <<'PYFIX'
import struct,zlib,pathlib
w,h=800,15000
chunk=lambda n,d:struct.pack('>I',len(d))+n+d+struct.pack('>I',zlib.crc32(n+d)&0xffffffff)
rows=b''.join(b'\0'+bytes((240-y%40,240-y%40,240-y%40))*w for y in range(h))
png=b'\x89PNG\r\n\x1a\n'+chunk(b'IHDR',struct.pack('>IIBBBBB',w,h,8,2,0,0,0))+chunk(b'IDAT',zlib.compress(rows))+chunk(b'IEND',b'')
pathlib.Path('.work/Photos-800x15000.png').write_bytes(png)
PYFIX
xcrun simctl addmedia "$TASK_DEVICE" .work/Photos-800x15000.png
TASK_STATUS=0
xcodebuild -project CookiesEditor.xcodeproj -scheme CookiesEditor -configuration Debug -destination "platform=iOS Simulator,id=$TASK_DEVICE" -parallel-testing-enabled NO -derivedDataPath .work/simulator -resultBundlePath "build/$TASK_SCREEN.xcresult" ARCHS=x86_64 ONLY_ACTIVE_ARCH=YES test > "build/test-$TASK_SCREEN.log" 2>&1 || TASK_STATUS=$?
if [[ "$TASK_STATUS" == 0 ]]; then
  # The full suite relaunches and clears test projects. Run Photos once last,
  # then inspect the real application container before another test resets it.
  xcodebuild -project CookiesEditor.xcodeproj -scheme CookiesEditor -configuration Debug -destination "platform=iOS Simulator,id=$TASK_DEVICE" -parallel-testing-enabled NO -derivedDataPath .work/simulator -resultBundlePath "build/$TASK_SCREEN-photos.xcresult" -only-testing:CookiesUITests/EditorUITests/testPhotosImportAndIPadOrientation ARCHS=x86_64 ONLY_ACTIVE_ARCH=YES test-without-building > "build/test-$TASK_SCREEN-photos.log" 2>&1 || TASK_STATUS=$?
  if [[ "$TASK_STATUS" == 0 ]]; then
    TASK_CONTAINER=$(xcrun simctl get_app_container "$TASK_DEVICE" com.cookies.editor.ios data)
    python3 scripts/verify_photos_import.py "$TASK_CONTAINER/Documents/Cookies" "build/photos-integrity-$TASK_SCREEN.json" || TASK_STATUS=$?
  fi
  xcrun xcresulttool export attachments --path "build/$TASK_SCREEN-photos.xcresult" --output-path "build/screenshots/$TASK_SCREEN-photos" || true
fi
if [[ "$TASK_STATUS" != 0 ]]; then
  xcrun xcresulttool export diagnostics --path "build/$TASK_SCREEN.xcresult" --output-path "build/diagnostics-$TASK_SCREEN" || true
  tail -100 "build/test-$TASK_SCREEN.log"
fi
xcrun xcresulttool export attachments --path "build/$TASK_SCREEN.xcresult" --output-path "build/screenshots/$TASK_SCREEN" || true
xcrun simctl shutdown "$TASK_DEVICE" || true
exit "$TASK_STATUS"
