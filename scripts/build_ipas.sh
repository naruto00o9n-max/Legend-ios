#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p build
TASK_REVISION=$(git rev-parse HEAD)
for TASK_SCHEME in CookiesEditor CookiesLocal; do
  if [[ "$TASK_SCHEME" == CookiesLocal ]]; then
    TASK_IPA=Cookies-Editor-Local-unsigned.ipa
    TASK_BUNDLE=com.cookies.editor.local
  else
    TASK_IPA=Cookies-Editor-unsigned.ipa
    TASK_BUNDLE=com.cookies.editor.ios
  fi
  xcodebuild -project CookiesEditor.xcodeproj -scheme "$TASK_SCHEME" -configuration Release -sdk iphoneos -destination 'generic/platform=iOS' -derivedDataPath ".work/device-$TASK_SCHEME" CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO "COOKIES_SOURCE_REVISION=$TASK_REVISION" build > "build/build-$TASK_SCHEME.log" 2>&1 || { tail -100 "build/build-$TASK_SCHEME.log"; exit 1; }
  TASK_APP=".work/device-$TASK_SCHEME/Build/Products/Release-iphoneos/CookiesEditor.app"
  test -f "$TASK_APP/CookiesEditor"
  file "$TASK_APP/CookiesEditor" | tee "build/binary-$TASK_SCHEME.txt"
  if codesign -d "$TASK_APP" > "build/signature-$TASK_SCHEME.txt" 2>&1; then
    echo "Unexpected signature on unsigned app"; exit 1
  fi
  test ! -e "$TASK_APP/embedded.mobileprovision"
  test ! -e "$TASK_APP/_CodeSignature"
  python3 scripts/verify_build_identity.py "$TASK_APP" "$TASK_BUNDLE" "$TASK_REVISION" "$TASK_SCHEME" "build/identity-$TASK_SCHEME.json"
  mkdir -p "build/package-$TASK_SCHEME/Payload"
  ditto "$TASK_APP" "build/package-$TASK_SCHEME/Payload/CookiesEditor.app"
  (cd "build/package-$TASK_SCHEME"; zip -q -r "../$TASK_IPA" Payload)
  rm -rf "build/package-$TASK_SCHEME"
done
shasum -a 256 build/*.ipa > build/ipa-sha256.txt
