# VoiceBridge

A personal Android app that bridges a language barrier between Gujarati-speaking grandparents and an English-speaking 4-year-old during WhatsApp video calls. Full vision: real-time voice translation that preserves the speaker's voice (record → STT → translate → voice-clone TTS → playback), with a two-phone acoustic relay. Built in staged chunks.

---

## Key Decisions

### Translation Service: Google Cloud Translation API v2

Chosen over three alternatives for Chunk 2:

| Service | Gujarati support | Credential reuse | Notes |
| :------ | :--------------- | :--------------- | :---- |
| **GCP Cloud Translation v2** | Yes (`gu`) | **Yes** -- same key as STT | Winner |
| DeepL | **No** | No | Eliminated immediately |
| Azure Translator | Yes | No -- separate Azure account | Extra setup, no synergy |
| OpenAI GPT-4o | Indirect (prompt-based) | No | Higher cost, different provider |

The same `GCP_STT_API_KEY` covers both STT and Translation when both APIs are enabled in the same GCP project. Free tier: 500K characters/month — sufficient for all development use.

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
│   │   ├── MainActivity.kt        ← Compose UI: Record / Stop / Play / Transcribe / Translate
│   │   ├── MainViewModel.kt       ← State machine, coroutines
│   │   ├── AudioRecorder.kt       ← AudioRecord → WAV file
│   │   ├── AudioPlayer.kt         ← MediaPlayer wrapper
│   │   ├── SttService.kt          ← GCP STT REST call (Gujarati)
│   │   └── TranslationService.kt  ← GCP Cloud Translation REST call (gu→en)
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
| 2 | Translation — Gujarati→English text via GCP Cloud Translation | ✅ Built |
| 3 | Voice cloning TTS | Not started |
| 4 | Real-time pipeline + two-phone relay | Not started |

---

## Building & Running (Android)

### Prerequisites

- JDK 17 or newer (the Chromebook dev box uses JDK 21) and the Android SDK
  (platform 35, build-tools 35.0.0). On Linux, `.claude/cloud-setup.sh` installs the SDK.
- A physical Android phone (API 24+) with wireless debugging on.
- The Gradle wrapper is committed (Gradle 9.3.1); no global Gradle needed.

### 1. Create `android/local.properties` (gitignored, never commit it)

```
sdk.dir=/home/<you>/Android/Sdk
GCP_STT_API_KEY=
```

Leave the key blank for Chunk 0. See `local.properties.template`.

### 2. Dev loop: build and install the debug build

```bash
cd android
./gradlew installDebug          # or, on the Chromebook: 115g vb (build + install + launch)
```

The debug build is `com.mananpatel.voicebridge.debug`, so it installs next to a release
build (`com.mananpatel.voicebridge`). Local builds report version `0.0.0-dev`.

Before a PR, run what CI runs: `./gradlew testDebugUnitTest lintDebug assembleDebug`.
Lint errors fail the build.

### 3. Releases

VoiceBridge follows the Android track of the shared release process:
[mananutils-platform runbook](https://github.com/mananpatel2491/mananutils-platform/blob/main/docs/release-process.md#android-apps).
The owner runs the tag commands; each takes `--dry-run`.

```bash
git push origin refs/heads/vX.Y.Z               # the version branch
python3 scripts/release.py rc X.Y.Z             # tag vX.Y.Z-rc.N -> signed APK on a GitHub pre-release
#   install it on the phone, work through .github/release-checklist.md, merge the PR
python3 scripts/release.py final X.Y.Z          # tag main vX.Y.Z -> promotes the rc's APK
python3 scripts/release.py cleanup X.Y.Z        # after deleting the rc pre-releases (see runbook)
```

The version comes from the tag (`versionName` X.Y.Z, `versionCode` X*10000+Y*100+Z). Release
APKs are signed in CI only; a release APK can't be installed over a build signed with
another key, so uninstall the old one first.

### 4. Acceptance test — Chunk 0

1. Launch the app on your phone.
2. Grant microphone permission when prompted.
3. Tap **Record**, say something, tap **Stop**.
4. Tap **Play** — you should hear the playback clearly.

---

## Providing API Credentials (Chunks 1 + 2)

Both STT (Chunk 1) and Translation (Chunk 2) use the **same GCP project and the same API key** — `GCP_STT_API_KEY`. You just need both APIs enabled.

1. Go to [console.cloud.google.com](https://console.cloud.google.com/) → create or select a project.
2. Enable both APIs (APIs & Services → Library):
   - **Cloud Speech-to-Text API** (for Chunk 1)
   - **Cloud Translation API** (for Chunk 2)
3. Create one API key (APIs & Services → Credentials → Create credentials → API key).
4. Paste it in `android/local.properties`:
   ```
   GCP_STT_API_KEY=AIza...
   ```
5. Rebuild and reinstall: `./gradlew installDebug`.

The key is injected at build time via `BuildConfig.GCP_STT_API_KEY` — it is NOT in source control.

The repo is public and the key ends up inside every APK, so the key is restricted: only
the two packages (`com.mananpatel.voicebridge` and `.debug`) with their signing-certificate
SHA-1s, only the Speech-to-Text and Translation APIs, and a per-day quota cap. The app sends
`X-Android-Package` / `X-Android-Cert` on each request for this. A build signed with a
different key (for example a new Chromebook's debug key) gets "Requests from this Android
client application are blocked" until its SHA-1 is added to the key.

### Chunk 1 acceptance test

1. Record yourself speaking Gujarati, tap Stop.
2. Tap **Transcribe (Gujarati)**.
3. A Gujarati transcript appears in the editable text field.
4. If the key is missing or invalid, a clear error card appears (no silent failure).

### Chunk 2 acceptance test

1. Complete the Chunk 1 acceptance test so the transcript field has Gujarati text.
2. Tap **Translate (English)**.
3. An English translation appears in the card below.
4. You can also skip recording: type or paste Gujarati text directly into the transcript field and tap Translate.
5. If the key is missing or `Cloud Translation API` is not enabled in the GCP project, a clear error card appears.

---

## Agentic Development Framework

This repo uses the **Agentic Vibe Fleet** methodology — see `GEMINI.md` (constitution) and `PATTERNS.md` (pattern registry).

### Spec-Driven Development (GitHub Spec Kit)

Every feature beyond a trivial fix runs the [Spec Kit](https://github.com/github/spec-kit) chain — **specify → clarify → plan → tasks → implement** (Claude Code: `/speckit-specify` …; Gemini CLI: `/speckit.specify` …) — producing durable planning artifacts in `specs/NNN-feature/`. This is the concrete implementation of the framework's 80/20 planning-first methodology. Governing principles live in `.specify/memory/constitution.md`, a distillation of `GEMINI.md` (which always wins on conflict).

To plan the next chunk:

```bash
.venv/bin/python scripts/generate_bootstrap_prompt.py "Add Gujarati-to-English translation using the Cloud Translation API"
```

Copy the generated prompt from `bootstrap_prompts/` into a Gemini session.

**Maintenance** (run after every feature; `.venv` is the project venv that `.claude/session-setup.sh` creates, or `python3 -m venv .venv && .venv/bin/pip install -r requirements.txt`):
```bash
.venv/bin/python scripts/verify_structure.py
.venv/bin/python scripts/optimize_changelog.py --dry-run
```
