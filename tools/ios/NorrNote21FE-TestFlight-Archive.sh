#!/usr/bin/env bash
# NORRVIND / NorrNote21FE iOS: build verified 0.7.0 (110) App Store Connect archive.
# Only creates an .xcarchive + log in ~/Downloads. Does not install/delete apps,
# update source files, access private notes, export credentials, or submit to Apple.
set -euo pipefail

ROOT="${NORRNOTE21FE_PROJECT_ROOT:-$HOME/Projects/NorrNote21FE/iOS/NorrNote21FE-iOS-I1}"
SCHEME='NorrNote21FEiOS'
BUNDLE='su.norrvind.norrnote.fe.ios'
WIDGET_BUNDLE='su.norrvind.norrnote.fe.ios.widget'
VERSION='0.7.0'
BUILD='110'
DEST="${NORRNOTE_TESTFLIGHT_OUTPUT_DIR:-$HOME/Downloads/NorrNote21FE-TestFlight}"
CHECK_ONLY=0
if [[ "${1:-}" == '--check' && "$#" -eq 1 ]]; then CHECK_ONLY=1
elif [[ "$#" -gt 0 ]]; then echo 'Usage: bash NorrNote21FE-TestFlight-Archive.sh [--check]' >&2; exit 2
fi

stop() { printf 'STOP: %s\n' "$*" >&2; exit 2; }
[[ -d "$ROOT" ]] || stop "Active project directory missing: $ROOT"
ROOT="$(cd "$ROOT" && pwd -P)"
case "$ROOT/" in
  */Tests/*|*/Fixtures/*|*/Backups/*|*/I3b3u-Backup/*|*/.patch-backups/*|*/DerivedData/*)
    stop 'Refusing backup/fixture project';;
esac
PROJECT="$ROOT/NorrNote21FEiOS.xcodeproj"
PBX="$PROJECT/project.pbxproj"
[[ -f "$PBX" ]] || stop 'Active Xcode project not found'
[[ -f "$ROOT/NorrNote21FEiOS/FEiOSRootView.swift" ]] || stop 'Active editor source missing'
[[ -f "$ROOT/NorrNoteWidget/NorrNoteHomeWidget.swift" ]] || stop 'Active widget source missing'
[[ -f "$ROOT/NorrNote21FEiOS/NorrNote21FEiOS.entitlements" ]] || stop 'App entitlements missing'
[[ -f "$ROOT/NorrNoteWidget/NorrNoteWidget.entitlements" ]] || stop 'Widget entitlements missing'
[[ -f "$ROOT/NorrNote21FEiOS/Assets.xcassets/AppIcon.appiconset/Contents.json" ]] || stop 'AppIcon asset missing'
# Publish exactly the source that the user tested as build 110; reject unrelated changes.
command -v shasum >/dev/null 2>&1 || stop 'macOS shasum command unavailable'
verify_source_hash() {
  local path="$1" expected="$2" actual
  actual="$(shasum -a 256 "$ROOT/$path" | awk '{print $1}')"
  [[ "$actual" == "$expected" ]] || stop "Source file differs from the verified stable 110: $path ($actual)"
}
verify_source_hash 'NorrNote21FEiOS/FEiOSRootView.swift' 'e7537b2f5a7ded6a102a71c5507343c5a6b1bb39594c333221835816aeea982e'
verify_source_hash 'NorrNote21FEiOS.xcodeproj/project.pbxproj' 'f771e6a88fb685677a22a3ef217dcac6409933b5adc51239e2dabeddded7e4b6'
verify_source_hash 'NorrNoteWidget/NorrNoteHomeWidget.swift' 'dd7e99a9b63db15fc48dd57207a1c4f91722068a21a91d081688d791ca8366fa'

version_entries="$(grep -Ec "CURRENT_PROJECT_VERSION = ${BUILD};" "$PBX" || true)"
[[ "$version_entries" == 4 ]] || stop "Expected exactly four build $BUILD entries (app + widget; Debug + Release), found $version_entries"
marketing_entries="$(grep -Ec "MARKETING_VERSION = ${VERSION};" "$PBX" || true)"
[[ "$marketing_entries" == 4 ]] || stop "Expected four marketing version $VERSION entries, found $marketing_entries"
for text in \
  "PRODUCT_BUNDLE_IDENTIFIER = $BUNDLE;" \
  "PRODUCT_BUNDLE_IDENTIFIER = $WIDGET_BUNDLE;" \
  'DEVELOPMENT_TEAM = 6F8BCV979D;' \
  'CODE_SIGN_STYLE = Automatic;'; do
  grep -Fq "$text" "$PBX" || stop "Unexpected signing/bundle configuration ($text)"
done

printf 'NorrNote21FE TestFlight PRECHECK PASS\n'
printf '  Source: %s\n  Version: %s (%s)\n  Bundle ID: %s\n' "$ROOT" "$VERSION" "$BUILD" "$BUNDLE"
printf '  Target: iPhone; Apple Team: 6F8BCV979D\n'
printf '  The Xcode project is currently iPhone-only (TARGETED_DEVICE_FAMILY=1).\n'
if [[ "$CHECK_ONLY" == 1 ]]; then
  printf '  CHECK ONLY: no archive was created.\n'
  exit 0
fi

for cmd in xcodebuild xcrun codesign open; do command -v "$cmd" >/dev/null 2>&1 || stop "Command not found: $cmd. Install/activate Xcode on the Mac."; done
[[ -x /usr/libexec/PlistBuddy ]] || stop '/usr/libexec/PlistBuddy not available (macOS required)'
mkdir -p "$DEST"
STAMP="$(date +%Y%m%d-%H%M%S)-$$"
ARCHIVE="$DEST/NorrNote21FE-${VERSION}-${BUILD}-${STAMP}.xcarchive"
LOG="$DEST/Archive-${VERSION}-${BUILD}-${STAMP}.log"
DERIVED="$(mktemp -d "${TMPDIR:-/tmp}/norrnote-testflight-derived.XXXXXX")"
trap 'rm -rf "$DERIVED"' EXIT

printf '\nXcode version:\n'
xcodebuild -version
printf '\nArchiving a Release build with App + Widget for App Store Connect...\n'
printf '  Log: %s\n' "$LOG"
if ! xcodebuild \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  -archivePath "$ARCHIVE" \
  -derivedDataPath "$DERIVED" \
  -allowProvisioningUpdates \
  archive >"$LOG" 2>&1; then
  echo 'ARCHIVE FAILED. Last Xcode errors/warnings:' >&2
  (grep -Ei 'error:|provisioning|signing|certificate|account|no profiles|failed' "$LOG" | tail -n 28 || true) >&2
  printf 'Full log: %s\n' "$LOG" >&2
  exit 3
fi

APP="$ARCHIVE/Products/Applications/NorrNote21FEiOS.app"
EXT="$APP/PlugIns/NorrNoteHomeWidget.appex"
[[ -d "$APP" ]] || stop "Archive built, but main .app missing: $APP"
[[ -d "$EXT" ]] || stop "Archive built, but Widget Extension missing: $EXT"
plist_value() { /usr/libexec/PlistBuddy -c "Print :$2" "$1"; }
APP_PLIST="$APP/Info.plist"
EXT_PLIST="$EXT/Info.plist"
[[ "$(plist_value "$APP_PLIST" CFBundleIdentifier)" == "$BUNDLE" ]] || stop 'Archived app bundle identifier mismatch'
[[ "$(plist_value "$EXT_PLIST" CFBundleIdentifier)" == "$WIDGET_BUNDLE" ]] || stop 'Archived widget bundle identifier mismatch'
[[ "$(plist_value "$APP_PLIST" CFBundleVersion)" == "$BUILD" ]] || stop 'Archived app build number mismatch'
[[ "$(plist_value "$EXT_PLIST" CFBundleVersion)" == "$BUILD" ]] || stop 'Archived widget build number mismatch'
[[ "$(plist_value "$APP_PLIST" CFBundleShortVersionString)" == "$VERSION" ]] || stop 'Archived app marketing version mismatch'
[[ "$(plist_value "$EXT_PLIST" CFBundleShortVersionString)" == "$VERSION" ]] || stop 'Archived widget marketing version mismatch'
codesign --verify --verbose=1 "$APP" || stop 'App code-signature validation failed'
codesign --verify --verbose=1 "$EXT" || stop 'Widget code-signature validation failed'

printf '\nARCHIVE READY FOR TESTFLIGHT\n'
printf '  %s\n' "$ARCHIVE"
printf '  Bundle: %s\n  Widget: %s\n  Version: %s (%s)\n' "$BUNDLE" "$WIDGET_BUNDLE" "$VERSION" "$BUILD"
printf '\nNEXT: In Xcode Organizer select this archive -> Distribute App -> App Store Connect -> Upload.\n'
printf 'If there is a choice, do NOT choose TestFlight Internal Only when external testers are intended.\n'
printf 'Ensure the app record for bundle ID %s exists at https://appstoreconnect.apple.com/\n' "$BUNDLE"
# Opening the archive only launches Organizer; it does NOT upload or distribute anything.
open -a Xcode "$ARCHIVE" || echo 'Open Xcode > Window > Organizer > Archives to upload manually.'
