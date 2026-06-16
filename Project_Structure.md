# Project Structure: VoiceBridge

This document provides a functional map of the codebase, enabling the Lead Agent (Gemini) to navigate and implement features with full architectural context.

## Core Framework (The 'Director' Layer)

| Path | Purpose |
| :--- | :--- |
| `GEMINI.md` | **Constitution**: The central nervous system and non-negotiable operating procedures. |
| `Project_Structure.md` | **Architecture Map**: This document. Functional mapping of the codebase. |
| `requirements.txt` | **Dependencies**: Python package requirements for the project. |
| `GEMINI_Getting_Started.md` | **Onboarding**: Auto-updated guide on using Gemini Code Assist features. |
| `PATTERNS.md` | **Pattern Registry**: Living document for established engineering patterns and design decisions. |
| `scripts/` | **Agentic Skills**: Maintenance and hygiene scripts accessible to agents. |
| `bruno/` | **API Validation**: Bruno collections and documentation for contract testing. |
| `bootstrap_prompts/` | **Plan Archive**: Systematic prompts generated from user intent to start new sessions. |
| `terraform/` | **Infrastructure-as-Code**: GCP/Terraform configuration for cost-gated deployments. |

## Application Layer

| Path | Purpose |
| :--- | :--- |
| `android/` | Android app project root (Kotlin + Jetpack Compose). |
| `android/app/src/main/java/com/mananpatel/voicebridge/MainActivity.kt` | **Entry point**: Compose UI — Record / Stop / Play / Transcribe buttons + permission flow. |
| `android/app/src/main/java/com/mananpatel/voicebridge/MainViewModel.kt` | **State machine**: recording state, transcript, error messages; launches STT coroutine. |
| `android/app/src/main/java/com/mananpatel/voicebridge/AudioRecorder.kt` | **AudioRecord wrapper**: captures PCM at 16 kHz/16-bit/mono, writes WAV file with header. |
| `android/app/src/main/java/com/mananpatel/voicebridge/AudioPlayer.kt` | **MediaPlayer wrapper**: plays back the recorded WAV file. |
| `android/app/src/main/java/com/mananpatel/voicebridge/SttService.kt` | **STT client**: strips WAV header, base64-encodes PCM, POSTs to GCP STT v1 (`gu-IN`). |
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
| `docs/architecture_overview.html` | **Visual Guide**: 1-page HTML overview of the framework. (Excluded from `verify_structure.py` checks) |
| `Function_Mapping.md` | **Traceability Map**: Correlates client components with backend pipeline endpoints. |

## Pipeline Stage Registry

| Stage | Role | Provider Interface | Current Implementation |
| :--- | :--- | :--- | :--- |
| Audio Capture | Microphone input / audio stream ingestion | `AudioCapture` | TBD |
| STT | Speech-to-Text transcription | `STTProvider` | TBD |
| LLM | Language model reasoning & response generation | `LLMProvider` | TBD |
| TTS | Text-to-Speech synthesis | `TTSProvider` | TBD |
| Audio Output | Speaker output / audio stream egress | `AudioOutput` | TBD |

## Changelog

| Date | Action | Files Affected | Summary |
| :--- | :--- | :--- | :--- |
| 2026-06-15 | INITIALIZE | `Project_Structure.md`, `GEMINI.md`, `README.md`, `.gitignore`, `LICENSE`, `PATTERNS.md`, `Function_Mapping.md`, `requirements.txt`, `scripts/README.md`, `scripts/generate_bootstrap_prompt.py`, `scripts/optimize_changelog.py`, `scripts/update_getting_started.py`, `scripts/verify_structure.py`, `bruno/README.md`, `terraform/README.md` | **V0.0.1 Baseline**: Director Layer operational. Voice pipeline constitution, pattern registry, and agentic skills scaffolded. Ready for autonomous vibe coding. |
| 2026-06-15 | ADD | `android/settings.gradle.kts`, `android/build.gradle.kts`, `android/gradle.properties`, `android/gradle/wrapper/gradle-wrapper.properties`, `android/local.properties.template`, `android/.gitignore`, `android/app/build.gradle.kts`, `android/app/proguard-rules.pro`, `android/app/src/main/AndroidManifest.xml`, `android/app/src/main/java/com/mananpatel/voicebridge/MainActivity.kt`, `android/app/src/main/java/com/mananpatel/voicebridge/MainViewModel.kt`, `android/app/src/main/java/com/mananpatel/voicebridge/AudioRecorder.kt`, `android/app/src/main/java/com/mananpatel/voicebridge/AudioPlayer.kt`, `android/app/src/main/java/com/mananpatel/voicebridge/SttService.kt`, `android/app/src/main/res/values/strings.xml`, `android/app/src/main/res/values/themes.xml` | **V0.0.2 Chunk 0+1**: Android app skeleton (Kotlin/Compose, AGP 9.1.1, Gradle 9.3.1). Chunk 0: AudioRecord→WAV pipeline, mic permission flow, record/stop/play UI. Chunk 1: GCP STT v1 REST integration (gu-IN, LINEAR16), API key injected via buildConfigField, full error surfacing. |
