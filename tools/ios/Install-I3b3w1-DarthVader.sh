#!/bin/bash
set -euo pipefail
PROJECT="$HOME/Projects/NorrNote21FE/iOS/NorrNote21FE-iOS-I1"
NAME="DarthVader_iPhone"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
[[ -f "$PROJECT/NorrNote21FEiOS.xcodeproj/project.pbxproj" ]] || exit 2
xcrun devicectl list devices --json-output "$TMP/devices.json" >/dev/null
DEVICE="$(python3 - "$TMP/devices.json" "$NAME" <<'PY'
import json,sys
d=json.load(open(sys.argv[1]))['result']['devices']
hits=[v['identifier'] for v in d if (v.get('deviceProperties') or {}).get('name')==sys.argv[2] and v.get('identifier')]
if len(hits)!=1:sys.exit('STOP: target iPhone is not unique')
print(hits[0])
PY
)"
read_build() {
 xcrun devicectl device info apps --device "$DEVICE" --json-output "$TMP/apps.json" >/dev/null
 python3 - "$TMP/apps.json" <<'PY'
import json,sys
a=json.load(open(sys.argv[1]))['result']['apps']
m=[x for x in a if x.get('bundleIdentifier')=='su.norrvind.norrnote.fe.ios']
if len(m)!=1:sys.exit('STOP: app not found')
print(m[0].get('bundleVersion','unknown'))
PY
}
BEFORE="$(read_build)"
echo "On $NAME before: $BEFORE"
[[ "$BEFORE" == 101 || "$BEFORE" == 102 ]] || { echo 'STOP: unexpected build or already 103'; exit 3; }
URL="https://raw.githubusercontent.com/yhelagin-dentalla/NorrNote21FE/ca25e27f603e6b9671e3832ed819ca3da79c7399/artifacts/ios/NorrNote21FE-iOS-I3b3w1.zip"
curl -fL "$URL" -o "$TMP/update.zip"
echo "da5d79caf072f8f586bd5f8e447731f6d6322174943a320d5068f999fef80fd1  $TMP/update.zip" | shasum -a 256 -c -
mkdir "$TMP/patch"; unzip -oq "$TMP/update.zip" -d "$TMP/patch"
bash "$TMP/patch/install.sh" --project "$PROJECT" --device "$DEVICE"
AFTER="$(read_build)"
echo "On $NAME after: $AFTER"
[[ "$AFTER" == 103 ]] || { echo 'STOP: build 103 not confirmed on device'; exit 5; }
echo 'VERIFIED: build 103 installed. Remove/re-add ONLY the Home Screen widget to see W103.'
