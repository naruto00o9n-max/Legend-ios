#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p build
for TASK_MODE in Editor; do
  xcodebuild -project CookiesEditor.xcodeproj -scheme "Cookies$TASK_MODE" -configuration Release -sdk iphoneos -destination 'generic/platform=iOS' -derivedDataPath ".work/device-$TASK_MODE" CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO build > "build/build-$TASK_MODE.log" 2>&1 || { tail -100 "build/build-$TASK_MODE.log"; exit 1; }
  TASK_APP=".work/device-$TASK_MODE/Build/Products/Release-iphoneos/CookiesEditor.app"
  test -f "$TASK_APP/CookiesEditor"
  file "$TASK_APP/CookiesEditor" | tee "build/binary-$TASK_MODE.txt"
  mkdir -p "build/package-$TASK_MODE/Payload"
  ditto "$TASK_APP" "build/package-$TASK_MODE/Payload/CookiesEditor.app"
  (cd "build/package-$TASK_MODE"; zip -q -r "../Cookies-Editor-unsigned.ipa" Payload)
  if codesign -d "$TASK_APP" > "build/signature-$TASK_MODE.txt" 2>&1; then
    echo "Unexpected signature on unsigned app"; exit 1
  fi
  test ! -e "$TASK_APP/embedded.mobileprovision"
  rm -rf "build/package-$TASK_MODE"
done
shasum -a 256 build/*.ipa > build/ipa-sha256.txt
