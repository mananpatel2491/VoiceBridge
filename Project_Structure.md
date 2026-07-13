# Project Structure: VoiceBridge

This document provides a functional map of the codebase, enabling the Lead Agent (Gemini) to navigate and implement features with full architectural context.

## Core Framework (The 'Director' Layer)

| Path | Purpose |
| :--- | :--- |
| `GEMINI.md` | **Constitution**: The central nervous system and non-negotiable operating procedures. |
| `Project_Structure.md` | **Architecture Map**: This document. Functional mapping of the codebase. |
| `requirements.txt` | **Dependencies**: Python package requirements for the project. |
| `PATTERNS.md` | **Pattern Registry**: Living document for established engineering patterns and design decisions. |
| `scripts/` | **Agentic Skills**: Maintenance and hygiene scripts accessible to agents. |
| `bruno/` | **API Validation**: Bruno collections and documentation for contract testing. |
| `terraform/` | **Infrastructure-as-Code**: GCP/Terraform configuration for cost-gated deployments. |
| `.specify/` | **Spec Kit Core**: GitHub Spec Kit toolkit — constitution distillation (`memory/constitution.md`), spec/plan/tasks templates, PowerShell helpers, workflow registry. |
| `specs/` | **Feature Specs**: Durable per-feature artifacts (`NNN-feature/spec.md`, `plan.md`, `tasks.md`) produced by the Spec Kit chain. (Created on first `/speckit-specify` run.) |
| `.claude/` | **Claude Code Integration**: Spec Kit skills (`/speckit-*` dash-form commands) + the 14-skill `voicebridge-*` repo-discipline library (v0.0.8; see `specs/006-*`) for Claude Code sessions. |
| `.gemini/` | **Gemini CLI Integration**: Spec Kit commands (`/speckit.*` dot-form TOML) for Gemini CLI sessions. |

## Application Layer

| Path | Purpose |
| :--- | :--- |
| `android/` | Android app project root (Kotlin + Jetpack Compose). |
| `android/app/src/main/java/com/mananpatel/voicebridge/MainActivity.kt` | **Entry point**: Compose UI — Record / Stop / Play / Transcribe buttons + permission flow. |
| `android/app/src/main/java/com/mananpatel/voicebridge/MainViewModel.kt` | **State machine**: recording state, transcript, error messages; launches STT coroutine. |
| `android/app/src/main/java/com/mananpatel/voicebridge/AudioRecorder.kt` | **AudioRecord wrapper**: captures PCM at 16 kHz/16-bit/mono, writes WAV file with header. |
| `android/app/src/main/java/com/mananpatel/voicebridge/AudioPlayer.kt` | **MediaPlayer wrapper**: plays back the recorded WAV file. |
| `android/app/src/main/java/com/mananpatel/voicebridge/SttService.kt` | **STT client**: strips WAV header, base64-encodes PCM, POSTs to GCP STT v1 (`gu-IN`). |
| `android/app/src/main/java/com/mananpatel/voicebridge/TranslationService.kt` | **Translation client**: POSTs text to GCP Cloud Translation v2 (`gu` -> `en`); same API key as STT. |
| `android/app/src/main/AndroidManifest.xml` | Declares `RECORD_AUDIO` + `INTERNET` permissions; launcher activity. |
| `android/app/src/main/res/values/strings.xml` | App string resources. |
| `android/app/src/main/res/values/themes.xml` | Minimal Material Light NoActionBar theme for Compose. |
| `android/app/build.gradle.kts` | App-level build config; injects `GCP_STT_API_KEY` from `local.properties` via `buildConfigField`. |
| `android/app/proguard-rules.pro` | Release ProGuard rules (debug builds skip ProGuard). |
| `android/build.gradle.kts` | Root build file; declares AGP 9.1.1 + Kotlin 2.0.21 plugin versions. |
| `android/settings.gradle.kts` | Declares project name and `:app` module. |
| `android/gradle.properties` | JVM heap, AndroidX flag, Kotlin code style. |
| `android/gradle/wrapper/gradle-wrapper.properties` | Pins Gradle 9.3.1 distribution URL. |
| `android/local.properties.template` | Documents required `local.properties` keys (`sdk.dir`, `GCP_STT_API_KEY`); gitignored original. |
| `android/.gitignore` | Excludes `local.properties`, build outputs, IDE files. |
| `android/scripts/smoke-test.ps1` | **Smoke test**: build gate, emulator boot, UIAutomator-driven Record/Stop/Play/Transcribe flow, screenshot-per-step, crash scan, optional `-AutoMerge` flag. |
| `android/scripts/install-hooks.ps1` | Copies hook templates from `android/scripts/hooks/` to `.git/hooks/` (run once per clone). |
| `android/scripts/hooks/post-commit` | Git hook template: runs smoke test on every commit on vX.Y.Z branches; auto-merges when CHANGELOG.md is updated. |
| `CHANGELOG.md` | Version history (Keep-a-Changelog format). Updating this in a commit is the auto-merge signal. |
| `docs/architecture_overview.html` | **Visual Guide**: 1-page HTML overview of the framework. (Excluded from `verify_structure.py` checks) |
| `Function_Mapping.md` | **Traceability Map**: Correlates client components with backend pipeline endpoints. (Rows are reserved-for-future-backend placeholders until the first backend ships.) |

## Pipeline Stage Registry

| Stage | Role | Provider Interface | Current Implementation |
| :--- | :--- | :--- | :--- |
| Audio Capture | Microphone input / audio stream ingestion | `AudioCapture` | `AudioRecorder.kt` (PCM 16-bit/16kHz/mono → WAV) |
| STT | Speech-to-Text transcription | `STTProvider` | `SttService.kt` (GCP STT v1, `gu-IN`) |
| Translation | Source-language text → target-language text | `TranslationProvider` | `TranslationService.kt` (GCP Cloud Translation v2, `gu`→`en`) |
| LLM | Language model reasoning & response generation | `LLMProvider` | TBD |
| TTS | Text-to-Speech synthesis | `TTSProvider` | TBD |
| Audio Output | Speaker output / audio stream egress | `AudioOutput` | `AudioPlayer.kt` (MediaPlayer) |

## Changelog

| Date | Action | Files Affected | Summary |
| :--- | :--- | :--- | :--- |
| 2026-06-15 | INITIALIZE | `Project_Structure.md`, `GEMINI.md`, `README.md`, `.gitignore`, `LICENSE`, `PATTERNS.md`, `Function_Mapping.md`, `requirements.txt`, `scripts/README.md`, `scripts/generate_bootstrap_prompt.py`, `scripts/optimize_changelog.py`, `scripts/update_getting_started.py`, `scripts/verify_structure.py`, `bruno/README.md`, `bruno/collections/.gitkeep`, `terraform/README.md`, `terraform/environments/.gitkeep`, `terraform/modules/.gitkeep` | **V0.0.1 Baseline**: Director Layer operational. Voice pipeline constitution, pattern registry, and agentic skills scaffolded. Ready for autonomous vibe coding. |
| 2026-06-15 | ADD | `android/settings.gradle.kts`, `android/build.gradle.kts`, `android/gradle.properties`, `android/gradle/wrapper/gradle-wrapper.properties`, `android/gradle/wrapper/gradle-wrapper.jar`, `android/gradlew`, `android/gradlew.bat`, `android/local.properties.template`, `android/.gitignore`, `android/app/build.gradle.kts`, `android/app/proguard-rules.pro`, `android/app/src/main/AndroidManifest.xml`, `android/app/src/main/java/com/mananpatel/voicebridge/MainActivity.kt`, `android/app/src/main/java/com/mananpatel/voicebridge/MainViewModel.kt`, `android/app/src/main/java/com/mananpatel/voicebridge/AudioRecorder.kt`, `android/app/src/main/java/com/mananpatel/voicebridge/AudioPlayer.kt`, `android/app/src/main/java/com/mananpatel/voicebridge/SttService.kt`, `android/app/src/main/res/values/strings.xml`, `android/app/src/main/res/values/themes.xml` | **V0.0.2 Chunk 0+1**: Android app skeleton (Kotlin/Compose, AGP 9.1.1, Gradle 9.3.1). Chunk 0: AudioRecord->WAV pipeline, mic permission flow, record/stop/play UI. Chunk 1: GCP STT v1 REST integration (gu-IN, LINEAR16), API key injected via buildConfigField, full error surfacing. |
| 2026-06-15 | ADD | `android/scripts/smoke-test.ps1`, `android/scripts/install-hooks.ps1`, `android/scripts/hooks/post-commit`, `CHANGELOG.md` | **V0.0.3 CI/CD**: Saraswati-pattern smoke test (build gate, UIAutomator UI drive, screenshot-per-step, crash scan, auto-merge flag). Post-commit hook auto-merges vX.Y.Z branch to main when CHANGELOG.md is updated and tests pass. `install-hooks.ps1` bootstraps hooks on fresh clone. |
| 2026-06-15 | UPDATE | `android/app/build.gradle.kts`, `PATTERNS.md`, `Project_Structure.md` | Added lint{} block (abortOnError=false, HTML report); added Git Workflow and Smoke Test patterns; updated architecture map with new files. |
| 2026-06-15 | ADD | `android/app/src/main/java/com/mananpatel/voicebridge/TranslationService.kt` | **V0.0.4 Chunk 2**: GCP Cloud Translation v2 REST client (`gu`→`en`); same GCP project/key as STT; editable transcript field in UI; Translate (English) button; translation result card; smoke test translate step. |
| 2026-06-15 | UPDATE | `android/app/src/main/java/com/mananpatel/voicebridge/MainViewModel.kt`, `android/app/src/main/java/com/mananpatel/voicebridge/MainActivity.kt`, `android/app/build.gradle.kts`, `android/scripts/smoke-test.ps1`, `CHANGELOG.md` | v0.0.4: translation state + actions in ViewModel; editable OutlinedTextField + Translate button + translation card in UI; version bump; smoke test translate flow. |
| 2026-07-05 | ADD | `.specify/`, `.claude/`, `.gemini/`, `GEMINI.md`, `PATTERNS.md`, `Project_Structure.md`, `README.md`, `scripts/verify_structure.py` | **v0.0.5 — GitHub Spec Kit adoption (dev tooling, $0/mo).** Initialized Spec Kit (Specify CLI v0.12.5) with Claude Code (skills, `/speckit-*`) and Gemini CLI (commands, `/speckit.*`) integrations. Seeded `.specify/memory/constitution.md` as a distillation of GEMINI.md + PATTERNS.md (GEMINI.md remains supreme). Codified the Spec-Driven Feature Workflow: the specify→clarify→plan→tasks→implement chain is the concrete implementation of the 80/20 planning phase, with durable artifacts in `specs/NNN-*/`. Tooling-only change — no infra, no cost. Also fixed `verify_structure.py` to skip gitignored local Android build outputs (`android/.gradle/`, `android/app/build/`, `android/local.properties`) so the gate passes on machines with local builds. |
| 2026-07-05 | ADD | `specs/001-agentic-framework-governance/`, `specs/002-voice-capture-playback/`, `specs/003-gujarati-stt/`, `specs/004-gujarati-english-translation/`, `specs/005-release-gate-automation/`, `CHANGELOG.md`, `Project_Structure.md` | **v0.0.6 — retro-spec conversion (docs only).** As-built Spec Kit sets for all delivered capabilities: 001 AVF governance + Spec Kit adoption (v0.0.1, v0.0.5), 002 voice capture & playback / Chunk 0 (v0.0.2), 003 Gujarati STT / Chunk 1 (v0.0.2), 004 Gujarati→English translation / Chunk 2 (v0.0.4), 005 release gate automation (v0.0.3 + 88ac97a). Full-7 artifacts per set, tasks marked [X] as-built with shipping versions, open gaps kept [ ]. No app code changes. |
| 2026-07-05 | UPDATE | `CHANGELOG.md`, `README.md`, `Project_Structure.md`, `Function_Mapping.md`, `specs/001-agentic-framework-governance/tasks.md`, `specs/005-release-gate-automation/tasks.md` | **v0.0.7 — docs drift fixes (docs only).** Added missing historical `[0.0.5]` changelog entry (005/T015) + `[0.0.7]` entry; README no longer claims the Gradle wrapper is uncommitted (wrapper IS tracked; copy-from-Saraswati bootstrap removed); ghost map rows removed (`GEMINI_Getting_Started.md`, `bootstrap_prompts/` — 001/T017); `Function_Mapping.md` placeholder rows annotated reserved-for-future-backend (001/T018). No app code changes, $0/mo. |
| 2026-07-13 | ADD | `.claude/skills/voicebridge-*/` (14 skill dirs), `specs/006-skill-library-distillation/`, `CHANGELOG.md`, `Project_Structure.md` | **v0.0.8 — agent skill library (docs+tooling only, $0/mo).** 14 `voicebridge-*` repo-discipline skills under `.claude/skills/` (runbooks for change control, debugging, release gate, build/env, diagnostics with executable `inspect_wav.py`/`grab_diag.ps1`, validation, docs, GCP/audio references, failure archaeology, Chunk-3 voice-clone-TTS campaign, research frontier), authored by parallel agents + 3-lens review (30 findings, all 19 blocking/important fixed — incl. the PowerShell 5.1 `exec-out >` binary-corruption trap). As-built spec set `specs/006-*`. Skill dirs mapped at directory level per the `.claude/` map row. No app code changes. |
