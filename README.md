# VoiceBridge

A personal Android app that bridges a language barrier between Gujarati-speaking grandparents and an English-speaking 4-year-old during WhatsApp video calls. Full vision: real-time voice translation that preserves the speaker's voice (record → STT → translate → voice-clone TTS → playback), with a two-phone acoustic relay. Built in staged chunks.

---

## Key Decisions

### Android Framework: Kotlin native + Jetpack Compose

Chosen over Flutter and React Native because:
- **Raw PCM access** — `AudioRecord`/`AudioTrack` give direct byte-buffer control with zero JNI overhead, which Chunk 4+ (real-time pipeline) requires.
- **No bridge latency** — Flutter/RN both add a platform-channel hop for audio I/O; unacceptable for near-real-time voice.
- **Compose** provides a concise, declarative UI with zero need for XML layouts.

### STT Service: Google Cloud Speech-to-Text v1 REST (`gu-IN`)

Chosen over OpenAI Whisper because:
- **Explicit `gu-IN` language code** with a dedicated acoustic model trained on Gujarati.
- Whisper supports Gujarati but its accuracy on that language is undertested in production use.
- Simple REST API — no vendor SDK required on Android.
- Free tier: 60 min/month — sufficient for all development testing.

### Audio Format: WAV (PCM 16-bit, 16 kHz, mono)

- `AudioRecord` produces raw PCM natively — WAV just wraps it with a 44-byte header.
- GCP STT accepts it as `LINEAR16` with no conversion step.
- Same PCM buffer format used in Chunk 4's real-time pipeline, so no format migration later.
- M4A/AAC was ruled out because GCP STT does not accept it without a decode step.

---

## Project Structure

```
VoiceBridge/
├── android/                    ← Android app (Kotlin + Compose)
│   ├── app/src/main/java/com/mananpatel/voicebridge/
│   │   ├── MainActivity.kt     ← Compose UI: Record / Stop / Play / Transcribe
│   │   ├── MainViewModel.kt    ← State machine, coroutines
│   │   ├── AudioRecorder.kt    ← AudioRecord → WAV file
│   │   ├── AudioPlayer.kt      ← MediaPlayer wrapper
│   │   └── SttService.kt       ← GCP STT REST call
│   └── local.properties.template
├── GEMINI.md                   ← Project Constitution (AI agent instructions)
├── PATTERNS.md                 ← Engineering pattern registry
├── Project_Structure.md        ← Architecture map + changelog
└── scripts/                    ← Agentic hygiene scripts
```

---

## Chunk Status

| Chunk | Description | Status |
| :---- | :---------- | :----- |
| 0 | Skeleton — mic permission, record/stop/play | ✅ Built |
| 1 | STT only — Gujarati transcription via GCP | ✅ Built |
| 2 | Translation (Gujarati ↔ English) | Not started |
| 3 | Voice cloning TTS | Not started |
| 4 | Real-time pipeline + two-phone relay | Not started |

---

## Building & Running (Android)

### Prerequisites

- Android SDK at `C:\Android` (or your machine's path)
- JDK 17
- A physical Android phone (API 24+) with USB debugging on

### 1. Copy the Gradle wrapper from Saraswati

The `gradle-wrapper.jar` binary is not committed. Run once to bootstrap:

```powershell
$src = "C:\Docs\Build\mananUtils\saraswati"
$dst = "C:\Docs\Build\mananUtils\VoiceBridge\android"
Copy-Item "$src\gradlew"     "$dst\gradlew"
Copy-Item "$src\gradlew.bat" "$dst\gradlew.bat"
Copy-Item "$src\gradle\wrapper\gradle-wrapper.jar" `
          "$dst\gradle\wrapper\gradle-wrapper.jar"
```

*(If you don't have Saraswati locally, run `gradle wrapper --gradle-version=9.3.1` from `android/` instead — requires Gradle on your PATH.)*

### 2. Create `android/local.properties`

```
# Windows SDK path
sdk.dir=C\:\\Android

# Chunk 1: GCP Speech-to-Text API key (leave blank for Chunk 0)
GCP_STT_API_KEY=
```

`local.properties` is gitignored — never commit it. See `local.properties.template` for reference.

### 3. Build and install

```powershell
cd C:\Docs\Build\mananUtils\VoiceBridge\android
.\gradlew assembleDebug
adb install app\build\outputs\apk\debug\app-debug.apk
```

### 4. Acceptance test — Chunk 0

1. Launch the app on your phone.
2. Grant microphone permission when prompted.
3. Tap **Record**, say something, tap **Stop**.
4. Tap **Play** — you should hear the playback clearly.

---

## Providing API Credentials (Chunk 1)

You need a Google Cloud API key with the **Cloud Speech-to-Text API** enabled.

1. Go to [console.cloud.google.com](https://console.cloud.google.com/) → create or select a project.
2. Enable **Cloud Speech-to-Text API** (APIs & Services → Library).
3. Create an API key (APIs & Services → Credentials → Create credentials → API key).
4. Paste it in `android/local.properties`:
   ```
   GCP_STT_API_KEY=AIza...
   ```
5. Rebuild: `.\gradlew assembleDebug` and reinstall.

The key is injected at build time via `BuildConfig.GCP_STT_API_KEY` — it is NOT in source control.

### Chunk 1 acceptance test

1. Record yourself speaking Gujarati, tap Stop.
2. Tap **Transcribe (Gujarati)**.
3. A Gujarati transcript appears on screen.
4. If the key is missing or invalid, a clear error card appears (no silent failure).

---

## Agentic Development Framework

This repo uses the **Agentic Vibe Fleet** methodology — see `GEMINI.md` (constitution) and `PATTERNS.md` (pattern registry). To plan the next chunk:

```bash
python ./scripts/generate_bootstrap_prompt.py "Add Gujarati-to-English translation using the Cloud Translation API"
```

Copy the generated prompt from `bootstrap_prompts/` into a Gemini session.

**Maintenance** (run after every feature):
```bash
python ./scripts/verify_structure.py
python ./scripts/optimize_changelog.py --dry-run
```
