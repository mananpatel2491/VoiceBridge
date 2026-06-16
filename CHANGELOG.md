# Changelog

All notable changes to VoiceBridge are documented here.
Format: [Keep a Changelog](https://keepachangelog.com/en/1.0.0/) / SemVer.

Rule: updating this file in a commit on a vX.Y.Z branch triggers the post-commit
hook to auto-merge that branch to main and push both to origin. See PATTERNS.md.

---

## [Unreleased]

## [0.0.3] - 2026-06-15
### Added
- Smoke test (`android/scripts/smoke-test.ps1`): build, emulator, UIAutomator-driven
  Record/Stop/Play/Transcribe flow, screenshot-per-step, crash scan, auto-merge flag
- Git hook (`android/scripts/hooks/post-commit`): runs smoke test on every commit on
  vX.Y.Z branches; auto-merges to main when CHANGELOG.md is updated in the commit
- Hook installer (`android/scripts/install-hooks.ps1`)
- `CHANGELOG.md` (this file)
- Lint block in `android/app/build.gradle.kts` (abortOnError=false, HTML report)
### Changed
- `PATTERNS.md`: added Git Workflow and Smoke Test patterns

## [0.0.2] - 2026-06-15
### Added
- Android app project (Kotlin + Jetpack Compose, AGP 9.1.1, Gradle 9.3.1, minSdk 24)
- **Chunk 0 -- Skeleton**: `AudioRecord` -> WAV (PCM 16-bit, 16 kHz, mono) recording
  pipeline; runtime `RECORD_AUDIO` permission with graceful deny message;
  Record / Stop / Play UI
- **Chunk 1 -- STT**: GCP Cloud Speech-to-Text v1 REST integration (`gu-IN`); WAV
  header stripped before upload; API key injected via `buildConfigField` from gitignored
  `local.properties`; full error surfacing (network, auth, empty audio, no speech)
### Decisions
- Framework: Kotlin native (raw PCM access, zero bridge latency for Chunk 4+)
- STT: Google Cloud STT `gu-IN` (explicit Gujarati acoustic model)
- Audio: WAV / LINEAR16 (no conversion between record and STT; same PCM format for
  the future real-time pipeline)

## [0.0.1] - 2026-06-15
### Added
- AVF framework scaffold: `GEMINI.md` constitution, `PATTERNS.md` pattern registry,
  `Project_Structure.md` architecture map, `Function_Mapping.md`
- Agentic skills: `generate_bootstrap_prompt.py`, `verify_structure.py`,
  `optimize_changelog.py`, `update_getting_started.py`
- Visual docs: `docs/architecture_overview.html`
- `README.md`, `LICENSE`, `requirements.txt`, `bruno/`, `terraform/`
