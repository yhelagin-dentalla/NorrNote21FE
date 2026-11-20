# NorrNote21FE iOS — публикация в TestFlight

Подготовка для подтверждённой версии `0.7.0 (110)`, Bundle ID `su.norrvind.norrnote.fe.ios`, Apple Team `6F8BCV979D`.

## Архив на Mac

Скачать `NorrNote21FE-TestFlight-Archive.sh` с GitHub и выполнить `bash ...`. Скрипт **не обновляет исходники**, не удаляет и не устанавливает приложения, не затрагивает заметки, не отправляет архив в Apple. Он проверяет именно рабочую версию 110, затем создаёт **Release .xcarchive**, проверяет Bundle IDs, номера сборок и подписи основного приложения и расширения виджета. Открывает архив в Xcode Organizer.

## Если приложения ещё нет в App Store Connect

Войти в https://appstoreconnect.apple.com/ → Apps → «+» → New App. Platform: iOS, Name: `NorrNote21 Friends Edition` (при условии доступности), Primary language: English (U.S.) или Russian, Bundle ID: `su.norrvind.norrnote.fe.ios`, SKU: например `NORRNOTE21FE-IOS`, User access: Full Access (или ограничить нужными пользователями). До этого убедиться, что Bundle ID зарегистрирован в Apple Developer и что App Groups настроены на App и Widget Extension. Не путать с коммерческим NorrNote и Scriptum Pro.

## Загрузка в TestFlight

Xcode → Window → Organizer → Archives → выбрать подготовленный архив → Distribute App → **App Store Connect** → **Upload** → Automatic signing → Upload. При намерении использовать внешних тестировщиков не выбирать **TestFlight Internal Only**. После обработки сборки зайти в App Store Connect → Apps → NorrNote21 Friends Edition → **TestFlight**. Если Apple запрашивает Export Compliance, ответить по фактической криптографии проекта; не выбирать ответ наугад.

Создать группу Internal Testing для участников App Store Connect, при необходимости группу External Testing для обычных тестировщиков. External Testing требует TestFlight App Review, описания для тестирования и контактных данных. Build остаётся на 90 дней. **Загрузка в TestFlight не публикует приложение в публичном App Store.**

## Рекомендуемые метаданные (EN)

**Beta App Description**:
> NorrNote21 Friends Edition is a private note-taking beta for iPhone. Create and organize notes, reminders and lists, use the Home Screen widget, mark tasks complete, and dictate note text using Apple speech recognition. Optional Google Drive features allow backup and synchronization.

**What to Test**:
> Please test creating and editing notes, saving changes, reminders, Home Screen widget display and task completion, and voice dictation. For dictation, speak a sentence, stop recording and check that the text is saved without repeated or reordered words. Report any errors or unexpected behavior.

**Feedback Email**: `support@norrvind.app`.

**Beta App Review Notes**:
> The app can be tested using local notes without signing into Google. Google Drive connection is optional. To test speech input, create a note without a PIN, open its editor, select the built-in voice input control, dictate a sentence and stop recording. To test the widget, add the Home Screen widget and tap a note's completion circle. No purchase or subscription is required.

**Важные моменты перед внешним тестом:** подтвердить актуальную политику конфиденциальности FE; проверить, что целевые тестировщики устанавливают приложение на совместимый iPhone. В исходном Xcode проекте `TARGETED_DEVICE_FAMILY = 1`, то есть пока нет нативной поддержки установки на iPad.

## Возможные ошибки

- Signing certificate / provisioning profile → Xcode Settings → Accounts → Apple Account, проверь Team, автоматически управляемую подпись и возможность регистрировать App Group.
- App ID not found → создать и зарегистрировать iOS App ID в Apple Developer; bundle ID должен совпадать **точно**.
- Archive version already uploaded → требуется новый CFBundleVersion и новая проверенная сборка, не перезагружать тот же номер.
- Invalid widget extension → проверить Bundle IDs, entitlements App Groups и embedded `.appex` в архиве.
