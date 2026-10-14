#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
TASK_SCREEN="${1:-ipad}"
TASK_STAGE="${2:-ui}"
TASK_FILTER="${3:-}"
TASK_UI_ARGUMENTS=(-only-testing:CookiesUITests)
if [[ -n "$TASK_FILTER" ]]; then
  TASK_UI_ARGUMENTS=()
  IFS=',' read -r -a TASK_CASES <<< "$TASK_FILTER"
  for TASK_CASE in "${TASK_CASES[@]}"; do
    [[ "$TASK_CASE" =~ ^CookiesUITests/EditorUITests/test[A-Za-z0-9]+$ ]] || { echo "Invalid UI test selector"; exit 2; }
    TASK_UI_ARGUMENTS+=("-only-testing:$TASK_CASE")
  done
fi
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
if [[ "$TASK_STAGE" == core ]]; then
  TASK_CORE_ARGUMENTS=(-only-testing:CookiesTests -only-testing:CookiesServicesTests -skip-testing:CookiesServicesTests/ServiceTests/testOriginalPublicAPIFromNativeClient)
  if [[ -n "${COOKIES_CORE_FILTER:-}" ]]; then
    [[ "$COOKIES_CORE_FILTER" == CookiesTests/RenderStabilityTests/testPersistentToolPreviewHonorsHiddenReorderedAndDrawingForeground ]] || { echo "Invalid native fixture retry selector"; exit 2; }
    TASK_CORE_ARGUMENTS=("-only-testing:$COOKIES_CORE_FILTER")
  fi
  TASK_STATUS=0
  xcodebuild -project CookiesEditor.xcodeproj -scheme CookiesEditor -configuration Debug -destination "platform=iOS Simulator,id=$TASK_DEVICE" -parallel-testing-enabled NO -derivedDataPath .work/simulator -resultBundlePath "build/$TASK_SCREEN-core.xcresult" "${TASK_CORE_ARGUMENTS[@]}" ARCHS=x86_64 ONLY_ACTIVE_ARCH=YES test > "build/test-$TASK_SCREEN-core.log" 2>&1 || TASK_STATUS=$?
  rg -n "\.swift:[0-9]+: error:|Test Case .* failed|Executed .* failures" "build/test-$TASK_SCREEN-core.log" | tail -35 || true
  xcrun xcresulttool export attachments --path "build/$TASK_SCREEN-core.xcresult" --output-path "build/whitening-$TASK_SCREEN" || true
  exit "$TASK_STATUS"
fi
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
# Build and install this revision before seeding Files. A focused UI run may
# have no previously installed app; skipping the fixture silently is invalid.
xcodebuild -project CookiesEditor.xcodeproj -scheme CookiesEditor -configuration Debug -destination "platform=iOS Simulator,id=$TASK_DEVICE" -parallel-testing-enabled NO -derivedDataPath .work/simulator ARCHS=x86_64 ONLY_ACTIVE_ARCH=YES build-for-testing > "build/test-$TASK_SCREEN-ui-build.log" 2>&1
xcrun simctl install "$TASK_DEVICE" .work/simulator/Build/Products/Debug-iphonesimulator/CookiesEditor.app
TASK_DOCUMENTS_CONTAINER=$(xcrun simctl get_app_container "$TASK_DEVICE" com.cookies.editor.ios data)
python3 - "$TASK_DOCUMENTS_CONTAINER" <<'PYFONT'
import pathlib,shutil,sys
font=next(pathlib.Path('App/Resources/Fonts').glob('*.ttf'))
target=pathlib.Path(sys.argv[1])/'Documents'/'Cookies-Import-Fixture.ttf'
target.parent.mkdir(parents=True,exist_ok=True)
shutil.copyfile(font,target)
assert target.is_file() and target.stat().st_size==font.stat().st_size
second=next(x for x in pathlib.Path('App/Resources/Fonts').glob('*.ttf') if x!=font)
shutil.copyfile(second,target.with_name('Cookies-Second-Fixture.ttf'))
print('Two distinct Files fixtures installed in the tested application container')
PYFONT
TASK_STATUS=0
xcodebuild -project CookiesEditor.xcodeproj -scheme CookiesEditor -configuration Debug -destination "platform=iOS Simulator,id=$TASK_DEVICE" -parallel-testing-enabled NO -derivedDataPath .work/simulator -resultBundlePath "build/$TASK_SCREEN.xcresult" "${TASK_UI_ARGUMENTS[@]}" ARCHS=x86_64 ONLY_ACTIVE_ARCH=YES test-without-building > "build/test-$TASK_SCREEN.log" 2>&1 || TASK_STATUS=$?
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
TASK_LOCAL_STATUS=$TASK_STATUS
# A third-party service outage must not prevent inspecting local Photos bytes.
# Keep both real service tests as separate mandatory gates; report their failure.
TASK_SERVICE_STATUS=0
xcodebuild -project CookiesEditor.xcodeproj -scheme CookiesEditor -configuration Debug -destination "platform=iOS Simulator,id=$TASK_DEVICE" -parallel-testing-enabled NO -derivedDataPath .work/simulator -resultBundlePath "build/$TASK_SCREEN-services.xcresult" -only-testing:CookiesServicesTests/ServiceTests/testOriginalPublicAPIFromNativeClient -only-testing:CookiesServicesUITests ARCHS=x86_64 ONLY_ACTIVE_ARCH=YES test-without-building > "build/test-$TASK_SCREEN-services.log" 2>&1 || TASK_SERVICE_STATUS=$?
xcrun xcresulttool export attachments --path "build/$TASK_SCREEN-services.xcresult" --output-path "build/screenshots/$TASK_SCREEN-services" || true
python3 - "$TASK_SCREEN" "$TASK_LOCAL_STATUS" "$TASK_SERVICE_STATUS" <<'PYGATES'
import json,pathlib,sys
screen,local,services=sys.argv[1:]
pathlib.Path('build/gates-'+screen+'.json').write_text(json.dumps({'local_editor_and_photos_exit_code':int(local),'real_external_services_exit_code':int(services),'external_failure_does_not_discard_local_evidence':True},indent=2)+'\n')
PYGATES
if [[ "$TASK_SERVICE_STATUS" != 0 ]]; then
  TASK_STATUS=$TASK_SERVICE_STATUS
  tail -100 "build/test-$TASK_SCREEN-services.log"
fi
if [[ "$TASK_STATUS" != 0 ]]; then
  xcrun xcresulttool export diagnostics --path "build/$TASK_SCREEN.xcresult" --output-path "build/diagnostics-$TASK_SCREEN" || true
  rg -n "\.swift:[0-9]+: error:|Test Case .* failed|Executed .* failures" "build/test-$TASK_SCREEN.log" | tail -35 || true
  tail -100 "build/test-$TASK_SCREEN.log"
fi
xcrun xcresulttool export attachments --path "build/$TASK_SCREEN.xcresult" --output-path "build/screenshots/$TASK_SCREEN" || true
xcrun simctl shutdown "$TASK_DEVICE" || true
exit "$TASK_STATUS"
