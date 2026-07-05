# Data Model: Release Gate Automation

No database and no app data. The capability's "data" is run artifacts, parameters, and the
signal conventions the hook consumes.

## Smoke-run artifact directory

`android/app/build/smoke-<yyyyMMdd-HHmmss>/` (gitignored; created at
`smoke-test.ps1:66-67,151`):

| Artifact | Producer | Purpose |
|---|---|---|
| `NN_<name>.png` (e.g. `01_launch.png` … `07_translate-result.png`) | `Save-Shot` (`smoke-test.ps1:142-148`) | numbered per-step visual evidence |
| `ui.xml` | `Get-Ui` (`smoke-test.ps1:80-83`) | last uiautomator dump (selector debugging) |

## Script parameters (defaults, `smoke-test.ps1:47-53`)

| Parameter | Default | Meaning |
|---|---|---|
| `-Build` | off | run `assembleDebug` before testing |
| `-AutoMerge` | off | on pass + `vX.Y.Z` branch: merge --no-ff to main, push both |
| `-AvdName` | `voicebridge_avd` | AVD to boot if no device online |
| `-JavaHome` | `C:\Program Files\Eclipse Adoptium\jdk-17.0.18.8-hotspot` | exported as `JAVA_HOME` |
| `-AndroidHome` | `C:\Android` | SDK root (adb/emulator paths derive from it) |

Fixed identifiers: `$AppId = "com.mananpatel.voicebridge"` (`smoke-test.ps1:60`), APK path
`app\build\outputs\apk\debug\app-debug.apk` (`smoke-test.ps1:65`).

## Hook routing table (`android/scripts/hooks/post-commit`)

| Branch | CHANGELOG.md in commit? | Action | Exit |
|---|---|---|---|
| not `^v\d+\.\d+\.\d+$` | — | no-op | 0 (`post-commit:14-17`) |
| `vX.Y.Z` | no | `smoke-test.ps1` (no build, no merge) | smoke exit (`post-commit:26-30`) |
| `vX.Y.Z` | yes | `smoke-test.ps1 -Build -AutoMerge` | smoke/merge exit (`post-commit:31-41`) |

Detection: `git show --name-only HEAD -- CHANGELOG.md | grep -c "CHANGELOG.md"`
(`post-commit:24`).

## Selector contract (mirrors specs 002–004 UI)

| Element | XPath predicate | Asserted states |
|---|---|---|
| Record | `@text='Record'` | initial=enabled, recording=disabled |
| Stop | `@text='Stop'` | initial=disabled, recording=enabled |
| Play | `@text='Play'` | initial=disabled, stopped=enabled |
| Transcribe | `contains(@text,'Transcribe')` | stopped=enabled |
| Translate | `contains(@text,'(English)')` | initial=disabled |
| Transcript field | `@content-desc='transcript-field'` | typing target |
| Crash markers | logcat `FATAL EXCEPTION\|E AndroidRuntime` | must be absent |

## Config / env keys

| Key | Set by | Consumed by |
|---|---|---|
| `JAVA_HOME`, `ANDROID_HOME` | script from parameters (`smoke-test.ps1:68-69`) | gradlew / adb / emulator |
| none persisted | — | the gate is stateless between runs |
