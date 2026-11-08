# NorrNote21FE iOS — I3b3u installation record

**Reported installed on physical iPhone:** 2026-11-08.  
**Validation:** pending; installation is not proof that the voice/editor regressions are fixed.

## Baselines

- `I3b3t`: last confirmed functioning Home Screen widget after an iPhone restart. Keep it as widget recovery baseline.
- `I3b3u`: current installed iOS patch, build version **101** (app and widget). Based on I3b3t.
- Exact original ZIP `NorrNote_fix_I3b3u.zip` is preserved in the private NORRVIND file library at `/NORRVIND/NorrNote21FE/iOS/WorkingWidget/NorrNote_fix_I3b3u.zip`.
- ZIP SHA-256: `4a5f0b5bd90222f3a339496a6a9bc16f027a321723050f17cbc53e0c9ed0b416`.

## Verified package differences vs I3b3t

- `NorrNoteWidget/NorrNoteHomeWidget.swift`: byte-identical to I3b3t.
- `NorrNoteWidget/Assets.xcassets/Contents.json`: byte-identical.
- `NorrNote21FEiOS.xcodeproj/project.pbxproj`: `CURRENT_PROJECT_VERSION` 100 → 101 in four app/widget build settings.
- `NorrNote21FEiOS/FEiOSRootView.swift`: editor lifecycle and speech recognizer changes; file SHA-256 `25d28769fc38a95a456e4e7e0cdd9a4d65e4ff0e672a6cc1e44c26b8f94fab02`.

## Changes requiring real-device regression testing

1. **VOICE-01:** voice transcription accumulates across short utterances and pauses; does not overwrite text already in note.
2. **EDIT-01:** title, body, date and time persist after tapping Done, closing/reopening the note and restarting the application.
3. Regression: widget still displays normally after iOS update; no data loss from editor dismissal or synchronization.

**Do not assume these fixes have passed until results are reported.** The patch ZIP is not a complete Xcode project. This GitHub document records project state; it does not distribute the binary patch or install anything. Do not expose user note databases, keys or OAuth credentials.
