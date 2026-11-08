#!/usr/bin/env bash
# NORRVIND / NorrNote21FE iOS: READ-ONLY on-device build inspection.
# Does not build, install, remove widgets/apps, change project files, or read notes.
set -euo pipefail
PROJECT_ROOT="${NORRNOTE21FE_PROJECT_ROOT:-$HOME/Projects/NorrNote21FE/iOS/NorrNote21FE-iOS-I1}"
BUNDLE="su.norrvind.norrnote.fe.ios"
for cmd in xcrun python3; do
  command -v "$cmd" >/dev/null || { echo "STOP: missing $cmd" >&2; exit 2; }
done
TEMP="$(mktemp -d "${TMPDIR:-/tmp}/norrnote-widget-audit.XXXXXX")"
trap 'rm -rf "$TEMP"' EXIT

echo 'NORRVIND / NorrNote21FE — read-only widget delivery audit'
echo 'No changes will be made to the iPhone or Xcode project.'
echo ''
if [[ -f "$PROJECT_ROOT/NorrNote21FEiOS.xcodeproj/project.pbxproj" ]]; then
  echo 'LOCAL PROJECT:'
  python3 - "$PROJECT_ROOT" <<'PY'
from pathlib import Path
import re,sys
root=Path(sys.argv[1]); text=(root/'NorrNote21FEiOS.xcodeproj/project.pbxproj').read_text(errors='replace')
versions=sorted(set(re.findall(r'CURRENT_PROJECT_VERSION\s*=\s*(\d+)\s*;',text)))
widget=root/'NorrNoteWidget/NorrNoteHomeWidget.swift'
code=widget.read_text(errors='replace') if widget.exists() else ''
print('  source versions (app/widget settings):', ', '.join(versions) or 'unknown')
print('  W103 in active widget source:', 'YES' if 'Text("W103")' in code else 'NO')
print('  AppIntent in widget source:', 'YES' if 'FEI3b3wMarkCompletedIntent' in code else 'NO')
print('  NorrNoteShip image reference:', 'YES' if 'Image("NorrNoteShip")' in code else 'NO')
PY
else
  echo 'LOCAL PROJECT: source project not found at the expected location.'
  echo "  $PROJECT_ROOT"
fi
echo ''
if [[ -n "${NORRNOTE_DEVICE:-}" ]]; then
  DEVICE="$NORRNOTE_DEVICE"
else
  if ! xcrun devicectl list devices --json-output "$TEMP/devices.json" >"$TEMP/device-error.txt" 2>&1; then
    echo 'DEVICE: cannot query paired iPhones. Connect/unlock iPhone and open Xcode Devices and Simulators.'
    tail -n 5 "$TEMP/device-error.txt" || true
    exit 3
  fi
  DEVICE="$(python3 - "$TEMP/devices.json" <<'PY'
import json,sys
try:
 data=json.load(open(sys.argv[1])); devices=data.get('result',{}).get('devices',[])
 matches=[]
 for d in devices:
  props=d.get('deviceProperties') or d.get('properties') or {}
  hw=d.get('hardwareProperties') or {}
  label=' '.join(str(x) for x in (props.get('name'),hw.get('marketingName'),props.get('productType'),hw.get('productType'),hw.get('deviceType')) if x)
  identifier=d.get('identifier')
  if identifier and 'iphone' in label.casefold():matches.append((identifier,label))
 print(matches[0][0] if len(matches)==1 else '')
 if len(matches)!=1:
  print(f'DEVICE: {len(matches)} iPhone candidates. Set NORRNOTE_DEVICE to the exact device ID to select one.',file=sys.stderr)
  for _,name in matches[:5]:print('  '+name,file=sys.stderr)
except Exception as e:print('DEVICE: cannot parse device list:',e,file=sys.stderr)
PY
)"
  if [[ -z "$DEVICE" ]]; then
    echo 'STOP: no unique iPhone selected. Read-only check ended.'
    exit 3
  fi
fi

echo 'ON IPHONE:'
if ! xcrun devicectl device info apps --device "$DEVICE" --json-output "$TEMP/apps.json" >"$TEMP/apps-error.txt" 2>&1; then
  echo '  Cannot read installed applications. Unlock iPhone and confirm it is connected to Xcode.'
  tail -n 5 "$TEMP/apps-error.txt" || true
  exit 4
fi
python3 - "$TEMP/apps.json" "$BUNDLE" <<'PY'
import json,sys
try:
 apps=json.load(open(sys.argv[1])).get('result',{}).get('apps',[])
except Exception as e:
 print('  Cannot parse installed-app list:',e)
 sys.exit(4)
match=[a for a in apps if a.get('bundleIdentifier')==sys.argv[2]]
if not match:
 print('  Target app',sys.argv[2],': NOT FOUND')
else:
 for a in match:
  v=str(a.get('bundleVersion') or '?')
  print('  Target bundle:',a.get('bundleIdentifier'))
  print('  Installed build (CFBundleVersion):',v)
  print('  Marketing version:',a.get('version') or '?')
  if v=='103':
   print('  DIAGNOSIS: build 103 installed; no W103 on widget means inspect WidgetKit cache/registration or a different widget instance.')
  elif v.isdigit() and int(v)<103:
   print('  DIAGNOSIS: iPhone app is older than patch 103 — latest build did NOT reach this device.')
  else:
   print('  DIAGNOSIS: unexpected/unknown build. Compare the installed bundle ID with Xcode product.')
other=[a for a in apps if a.get('bundleIdentifier')!=sys.argv[2] and ('norrnote' in str(a.get('name','')).casefold() or 'norrnote' in str(a.get('bundleIdentifier','')).casefold())]
for a in other[:10]:
 print('  Other similarly named app:',a.get('bundleIdentifier'), 'build',a.get('bundleVersion'))
PY

echo ''
if [[ -d "$PROJECT_ROOT/.patch-backups" ]]; then
 echo 'RECENT PATCH INSTALL LOGS (existence only):'
 python3 - "$PROJECT_ROOT/.patch-backups" <<'PY'
from pathlib import Path
import sys
files=sorted(Path(sys.argv[1]).glob('I3b3w1-*/devicectl-install.log'),key=lambda p:p.stat().st_mtime,reverse=True)
if not files:print('  None found: installer may not have reached the device-install step.')
for f in files[:3]:
 s=f.read_text(errors='replace')
 print(' ',f.parent.name, 'install log:', 'non-empty' if s.strip() else 'empty', 'error:', ('YES' if 'error' in s.lower() else 'not found'))
PY
fi
echo ''
echo 'REPORT COMPLETE. Copy only the LOCAL PROJECT and ON IPHONE sections into ChatGPT.'