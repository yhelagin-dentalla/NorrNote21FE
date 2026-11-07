#!/bin/bash
# NorrNote21FE iOS targeted source collection for voice + editor persistence diagnosis.
# READ ONLY: does not modify Xcode project, user notes, databases, Google Drive, or WidgetKit.
set -euo pipefail

ROOT="${NORRNOTE21FE_ROOT:-${HOME}/Projects/NorrNote21FE}"
DOWNLOADS="${HOME}/Downloads"
if [ ! -d "$ROOT" ]; then
  printf 'ОШИБКА: проект не найден: %s\n' "$ROOT" >&2
  exit 2
fi
if ! command -v zip >/dev/null 2>&1; then
  echo 'ОШИБКА: не найден системный zip.' >&2
  exit 2
fi
PROJECT="$(find "$ROOT" -type d -name 'NorrNote21FEiOS.xcodeproj' \
  ! -path '*/Backups/*' ! -path '*/.patch-backups/*' ! -path '*/DerivedData/*' \
  -print | LC_ALL=C sort | head -n 1)"
if [ -z "$PROJECT" ]; then
  echo 'ОШИБКА: NorrNote21FEiOS.xcodeproj не найден; ничего не изменено.' >&2
  exit 2
fi

STAMP="$(date '+%Y%m%d-%H%M%S')"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/norrnote-fe-diagnostics.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT
DEST="$TMP/NorrNote21FE-iOS-Bugfix-Sources"
mkdir -p "$DEST/source" "$DOWNLOADS"
SELECTED=0
SKIPPED_SENSITIVE=0
SKIPPED_LARGE=0

# Only Swift source files in the active iOS/Shared tree. No databases, media, OAuth plists or tokens.
while IFS= read -r -d '' F; do
  case "$F" in
    */.git/*|*/Backups/*|*/Backup/*|*/backups/*|*/.patch-backups/*|*/Patch/*|*/Patches/*|*/Archive/*|*/Archived/*|*/Old/*|*/Docs/*|*/Reference/*|*/DerivedData/*|*/.build/*|*/build/*|*/Build/*|*/NorrNoteWidget/*|*/Pods/*|*/Carthage/*)
      continue;;
  esac
  BASENAME="${F##*/}"
  case "$BASENAME" in
    FEiOSRootView.swift|FEiOSStore.swift|FEiOSWire.swift|NorrNote21FEiOSApp.swift|FESync21Merge.swift|FELanguage.swift|FEGoogleDriveInspector.swift|*Voice*.swift|*Speech*.swift|*Dictat*.swift|*Editor*.swift|*Note*.swift|*Store*.swift|*Sync*.swift|*Model*.swift|*Persistence*.swift)
      ;;
    *) continue;;
  esac
  BYTES="$(wc -c < "$F" | tr -d ' ')"
  if [ "$BYTES" -gt 3145728 ]; then
    SKIPPED_LARGE=$((SKIPPED_LARGE + 1))
    continue
  fi
  # Do not export common hard-coded secret formats accidentally embedded in Swift.
  if LC_ALL=C grep -Eq '(-----BEGIN (RSA |EC |OPENSSH )?PRIVATE KEY-----|AIza[0-9A-Za-z_-]{25,}|sk-[a-zA-Z0-9_-]{25,})' "$F" 2>/dev/null; then
    SKIPPED_SENSITIVE=$((SKIPPED_SENSITIVE + 1))
    continue
  fi
  REL="${F#"$ROOT"/}"
  mkdir -p "$DEST/source/$(dirname "$REL")"
  cp -p "$F" "$DEST/source/$REL"
  SELECTED=$((SELECTED + 1))
done < <(find "$ROOT" -type f -name '*.swift' -print0)

if [ "$SELECTED" -lt 2 ]; then
  echo 'ОШИБКА: недостаточно актуальных Swift-исходников найдено. Архив не создан.' >&2
  exit 3
fi

# Xcode build configuration is useful to check target membership; it contains no user note data.
PROJECT_REL="${PROJECT#"$ROOT"/}"
if [ -f "$PROJECT/project.pbxproj" ]; then
  mkdir -p "$DEST/source/$PROJECT_REL"
  cp -p "$PROJECT/project.pbxproj" "$DEST/source/$PROJECT_REL/project.pbxproj"
fi

{
  echo 'NorrNote21FE iOS: editor + voice source snapshot (read-only)'
  echo "Captured: $(date '+%Y-%m-%d %H:%M:%S %z')"
  echo "Xcode project relative path: $PROJECT_REL"
  echo "Swift files captured: $SELECTED"
  echo "Swift files skipped as possibly containing secrets: $SKIPPED_SENSITIVE"
  echo "Swift files skipped > 3MiB: $SKIPPED_LARGE"
  echo 'NOT included: WidgetKit sources, local databases, notes, attachments, passwords, auth configuration and application data.'
  echo 'The script changes no files in the project. Review the resulting archive before sharing if needed.'
} > "$DEST/README.txt"
(
  cd "$DEST"
  find source -type f -print | LC_ALL=C sort > files.txt
  while IFS= read -r FILE; do
    shasum -a 256 "$FILE"
  done < files.txt > SHA256SUMS.txt
)
OUT="$DOWNLOADS/NorrNote21FE-iOS-EditorVoice-Sources-$STAMP.zip"
(cd "$TMP" && zip -X -qr "$OUT" "$(basename "$DEST")")
unzip -tq "$OUT" >/dev/null
printf '\nГОТОВО: %s\n' "$OUT"
printf 'Исходных Swift-файлов: %s\n' "$SELECTED"
printf 'Пропущено по признаку секретов: %s; из-за размера: %s\n' "$SKIPPED_SENSITIVE" "$SKIPPED_LARGE"
printf 'Отправьте этот ZIP в чат для точечного исправления голосового ввода и сохранения заметок.\n'