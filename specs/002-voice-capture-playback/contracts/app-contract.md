# App Contract: VoiceBridge Android surface (as of v0.0.5)

The externally observable Android app surface. UI labels double as the smoke test's selector
contract (`android/scripts/smoke-test.ps1:26,42` — "KEEP IN SYNC with MainActivity.kt").

## Identity & entry points

| Item | Value | Source |
|---|---|---|
| applicationId / namespace | `com.mananpatel.voicebridge` | `android/app/build.gradle.kts:15,19` |
| Launcher activity | `.MainActivity` (exported, MAIN/LAUNCHER) | `AndroidManifest.xml:11-18` |
| versionCode / versionName | 4 / "0.0.4" (unchanged by tooling-only v0.0.5) | `android/app/build.gradle.kts:22-23` |
| minSdk / targetSdk / compileSdk | 24 / 35 / 35 | `android/app/build.gradle.kts:16,20-21` |

## Permissions

| Permission | Why | Source |
|---|---|---|
| `android.permission.RECORD_AUDIO` | mic capture; runtime-requested on launch | `AndroidManifest.xml:4`; `MainActivity.kt:51-59` |
| `android.permission.INTERNET` | GCP STT/Translation REST calls | `AndroidManifest.xml:5` |

`allowBackup=false` (`AndroidManifest.xml:8`). No services, receivers, workers, or extra
activities — single-screen app.

## Screen contract (single Compose screen, `MainActivity.kt:40-200`)

| Element | Selector (smoke test) | Enablement rule |
|---|---|---|
| Title `VoiceBridge` | `contains(@text,'VoiceBridge')` | always |
| `Record` button | `@text='Record'` | permission granted AND not RECORDING (`MainActivity.kt:114`) |
| `Stop` button | `@text='Stop'` | RECORDING only (`MainActivity.kt:119`) |
| `Play` button | `@text='Play'` | hasRecording AND not RECORDING (`MainActivity.kt:125`) |
| `Transcribe (Gujarati)` button | `contains(@text,'Transcribe')` | hasRecording AND idle (spec 003) |
| Transcript field | `@content-desc='transcript-field'` (`MainActivity.kt:160`) | disabled while transcribing/translating |
| `Translate (English)` button | `contains(@text,'(English)')` | transcript non-blank AND idle (spec 004) |
| Error card | text starts `Error: ` (`MainActivity.kt:101`) | shown when `errorMessage != null` |
| Permission-denied card | contains "Microphone permission denied." | shown after denial |

## State machine (observable via semantics)

`IDLE → (Record) → RECORDING → (Stop) → STOPPED` (`MainViewModel.kt:11`); Compose Material3
propagates `enabled` into the accessibility tree, which is how the smoke test asserts the
matrix (`android/scripts/smoke-test.ps1:128-140`).

## Intents / IPC

None beyond the launcher intent. No deep links, no exported components other than
MainActivity's launcher filter.
