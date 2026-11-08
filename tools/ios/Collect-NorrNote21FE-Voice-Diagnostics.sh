#!/usr/bin/env bash
# NORRVIND NorrNote21FE iOS speech diagnostics snapshot.
# Read-only: it does not launch, build, install or alter an app, device, project, or notes.
set -euo pipefail
ROOT="${NORRNOTE21FE_PROJECT_ROOT:-$HOME/Projects/NorrNote21FE/iOS/NorrNote21FE-iOS-I1}"
OUTDIR="${HOME}/Downloads"
[[ -f "$ROOT/NorrNote21FEiOS.xcodeproj/project.pbxproj" ]] || {
  printf 'STOP: active Xcode project not found: %s\n' "$ROOT" >&2; exit 2;
}
for cmd in python3 zip unzip shasum; do command -v "$cmd" >/dev/null 2>&1 || { echo "STOP: missing $cmd" >&2; exit 2; }; done
mkdir -p "$OUTDIR"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/norrnote-voice.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT
D="$TMP/NorrNote21FE-Voice-Diagnostics"
mkdir -p "$D/sources"
# Select only the live project tree. Never walk sibling backups/fixtures.
python3 - "$ROOT" "$D" <<'PY'
from pathlib import Path
import hashlib, json, re, shutil, sys, time
root = Path(sys.argv[1]).resolve()
out = Path(sys.argv[2])
exclude = {'.git', '.build', '.patch-backups', 'Backups','Backup', 'backups','I3b3u-Backup','Tests','Fixtures','DerivedData','Pods','Carthage','build','Build','Archive','Archives','Old','Patches','Signing','Docs','Reference'}
private = re.compile(r'(-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----|AIza[0-9A-Za-z_-]{25,}|sk-[A-Za-z0-9_-]{25,}|client_secret|refresh_token\s*[:=]|private_key\s*[:=])',re.I)
needles = ['FEiOSAudioSessionCoordinator', 'SFSpeechRecognizer', 'SFSpeechRecognitionTask','SFSpeechAudioBufferRecognitionRequest', 'AVAudioEngine', 'AVAudioSession', 'AVAudioApplication', 'SpeechAnalyzer', 'SpeechTranscriber']
chosen=[]; skipped=[]
for path in root.rglob('*.swift'):
    rel=path.relative_to(root)
    if any(p in exclude or p.startswith('.') and p not in {'.swift'} for p in rel.parts[:-1]): continue
    if path.is_symlink() or path.stat().st_size > 2_000_000: continue
    try: text=path.read_text(encoding='utf-8',errors='replace')
    except Exception: continue
    name=path.name.lower()
    choose = any(n in text for n in needles) or any(s in name for s in ('audio','voice','speech','dictat')) or path.name in ('FEiOSRootView.swift','NorrNote21FEiOSApp.swift')
    if not choose: continue
    if private.search(text): skipped.append(str(rel)); continue
    target=out/'sources'/rel
    target.parent.mkdir(parents=True,exist_ok=True)
    shutil.copy2(path,target)
    chosen.append((str(rel),hashlib.sha256(path.read_bytes()).hexdigest(),len(text)))
# Xcode build settings (without exporting any local provisioning profiles, entitlements, tokens or OAuth plists).
pbx = root/'NorrNote21FEiOS.xcodeproj/project.pbxproj'
text=pbx.read_text(encoding='utf-8',errors='replace')
if not private.search(text):
    dest=out/'sources/NorrNote21FEiOS.xcodeproj/project.pbxproj'
    dest.parent.mkdir(parents=True,exist_ok=True); shutil.copy2(pbx,dest)
    chosen.append(('NorrNote21FEiOS.xcodeproj/project.pbxproj',hashlib.sha256(pbx.read_bytes()).hexdigest(),len(text)))
info = {
    'purpose':'speech capture and recognition code review (no personal notes)',
    'active_project': str(root),
    'timestamp_local':time.strftime('%Y-%m-%d %H:%M:%S %z'),
    'source_build_versions':sorted(set(re.findall(r'CURRENT_PROJECT_VERSION\s*=\s*(\d+)',text))),
    'info_plist_keys_in_build_config':{k: bool(re.search(k,text)) for k in ['NSSpeechRecognitionUsageDescription','NSMicrophoneUsageDescription']},
    'files': [{'path':a,'sha256':b,'approx_characters':c} for a,b,c in chosen],
    'skipped_possible_credentials':skipped,
    'exclusions':'No app data, note databases, Drive sync files, attachments, signing keys, profiles, phone logs, or saved recordings.'
}
(out/'SUMMARY.json').write_text(json.dumps(info,ensure_ascii=False,indent=2),encoding='utf-8')
if not any('FEiOSRootView.swift' in item[0] for item in chosen):
    raise SystemExit('STOP: active editor Swift file missing/blocked; no useful archive created')
print('Selected files:',len(chosen),'Sensitive-file skips:',len(skipped))
if not any(any(s in item[0].lower() for s in ('audio','speech','voice')) and 'FEiOSRootView' not in item[0] for item in chosen):
    print('NOTE: audio coordinator source was not found as a separate file; inspect project layout.')
PY
# Optional read-only device build verification; raw device/app lists stay in TMP, never shared.
if command -v xcrun >/dev/null 2>&1; then
  TARGET_NAME="${NORRNOTE_DEVICE_NAME:-DarthVader_iPhone}"
  if xcrun devicectl list devices --json-output "$TMP/devices.json" >/dev/null 2>&1; then
    DEVICE="$(python3 - "$TMP/devices.json" "$TARGET_NAME" <<'PYDEVICE'
import json,sys
try:
  devices=json.load(open(sys.argv[1],encoding='utf-8')).get('result',{}).get('devices',[])
  hits=[d.get('identifier') for d in devices if (d.get('deviceProperties') or {}).get('name')==sys.argv[2] and d.get('identifier')]
  print(hits[0] if len(hits)==1 else '')
except Exception:print('')
PYDEVICE
)"
    if [[ -n "$DEVICE" ]] && xcrun devicectl device info apps --device "$DEVICE" --json-output "$TMP/apps.json" >/dev/null 2>&1; then
      python3 - "$TMP/apps.json" "$D/SUMMARY.json" <<'PYBUILD'
import json,sys
try:
  apps=json.load(open(sys.argv[1],encoding='utf-8')).get('result',{}).get('apps',[])
  found=[a for a in apps if a.get('bundleIdentifier')=='su.norrvind.norrnote.fe.ios']
  data=json.load(open(sys.argv[2],encoding='utf-8'))
  data['installed_build_on_target_iPhone'] = str(found[0].get('bundleVersion','unknown')) if len(found)==1 else 'app not found'
  with open(sys.argv[2],'w',encoding='utf-8') as f:json.dump(data,f,ensure_ascii=False,indent=2)
  print('Confirmed app build on iPhone:',data['installed_build_on_target_iPhone'])
except Exception as e:print('NOTE: on-device version unavailable:',type(e).__name__)
PYBUILD
    else
      echo 'NOTE: target iPhone not connected/unlocked; installed build cannot be confirmed.'
    fi
  fi
fi
STAMP="$(date '+%Y%m%d-%H%M%S')"
ZIP="$OUTDIR/NorrNote21FE-Voice-Diagnostics-$STAMP.zip"
(cd "$TMP" && zip -q -X -r "$ZIP" NorrNote21FE-Voice-Diagnostics)
unzip -tq "$ZIP" >/dev/null
printf '\nREADY: %s\n' "$ZIP"
printf 'Review archive before sharing; only source code and build settings are included.\n'