# Pattern Registry: VoiceBridge

This document records established engineering patterns and design decisions to ensure consistency and avoid "GIST debt".

## 1. Architectural Patterns

*   **Cross-Platform Automation**: All project maintenance and hygiene scripts must be written in Python to ensure compatibility across Windows, macOS, and Linux. Shell-specific scripts (Bash/PowerShell) are permitted only in specialized, hardened environments where a Python runtime is strictly prohibited.
*   **Non-Hardcoded LLM Selection**: Scripts interacting with LLMs must dynamically query available models rather than using hardcoded strings. This prevents breaking changes when models are deprecated or updated.
*   **Automation-First CLI**: All interactive scripts must support CLI arguments to bypass user input (e.g., `--model`) and allow for safe previewing of actions (e.g., `--dry-run`). This ensures scripts are compatible with CRON jobs and CI/CD pipelines.
*   **Contract-First Validation (Bruno)**: Every new API-exposed backend function requires a corresponding Bruno script. Commits are blocked unless Bruno validation passes. Exceptions require an explicit owner acknowledgment in the commit message: `"I understand bruno validation is failing and I allow the exception to have the code committed to github repo"`.
*   **Full-Stack Traceability Mapping**: Maintain a functional mapping between frontend components and backend endpoints in `Function_Mapping.md`. This map must be updated whenever functions are added, updated, or deleted to ensure cross-layer integrity.
*   **Proactive Hardening**: When updating an existing file, the agent must audit the logic for security risks (e.g., injection, leaked secrets, audio data leakage) and resource/memory leaks. If found, these must be patched immediately and logic added to prevent reintroduction.
*   **Production Readiness Gating**: Code containing comments indicating temporary setups, mocks, or non-production quality (e.g., `// TODO: temp`, `// fix later`) must be flagged. The agent must explicitly ask the Director if these should be addressed before proceeding.
*   **Infrastructure Migration Advisory**: When transitioning from local/mock implementations to production-ready infrastructure, the agent must present a comparative selection of technology options and seek the Director's arbitration before implementation.

*   **Spec-Driven Feature Workflow (Spec Kit)**: Features beyond trivial fixes run the GitHub Spec Kit chain (`specify → clarify → plan → tasks → implement`), producing durable artifacts in `specs/NNN-*/`. The Spec Kit constitution (`.specify/memory/constitution.md`) is always a *distillation* of the repo's own constitution (`GEMINI.md`) + `PATTERNS.md` with an explicit precedence header — it never introduces new rules. On conflict, GEMINI.md wins.

## 2. Voice Pipeline Patterns

*   **Provider Interface Pattern**: Each pipeline stage (STT, LLM, TTS) must be implemented behind an abstract provider interface. Concrete implementations (e.g., `WhisperSTT`, `GeminiLLM`, `ElevenLabsTTS`) are injected at runtime. Never call a vendor SDK directly from business logic.
*   **Streaming-First Design**: All pipeline stages must expose a streaming API. Buffered (non-streaming) calls are acceptable only for batch processing use cases explicitly marked as such in the changelog.
*   **VAD Gating**: Voice Activity Detection must gate STT calls to prevent sending silence to paid APIs. The VAD threshold, frame size, and silence timeout must be documented in this file when set.
*   **Audio Format Contract**: All audio exchanged between pipeline stages must be PCM 16-bit, 16 kHz, mono, unless an exception is documented below with rationale.
*   **Latency Budget Tracking**: Each pipeline hop has a latency budget. When a new stage is added, its expected P50/P95 latency must be noted in `Project_Structure.md`.

## 3. Coding Standards

*   **CLI Argument Parsing**: Use the standard `argparse` library for all scripts to provide a consistent interface for flags and help menus.
*   **Async-First**: Voice pipeline components that perform I/O (network, audio device) must use `asyncio`. Synchronous calls in an async context require explicit justification in the code.

## 4. Git Workflow and Releases

*   **Shared release process**: VoiceBridge follows the Android track of the mananutils-platform release process ([runbook](https://github.com/mananpatel2491/mananutils-platform/blob/main/docs/release-process.md#android-apps)). Since v0.1.0 it replaces the PowerShell post-commit gate (smoke test + auto-merge + push), which is retired.
*   **Version Branches**: All work for a version is done on a branch named `vX.Y.Z`, pushed with `git push origin refs/heads/vX.Y.Z`. Never commit directly to `main`. Changes reach `main` through a PR (CI must be green), never by a hook.
*   **Release candidates**: `python3 scripts/release.py rc X.Y.Z` tags the pushed branch `vX.Y.Z-rc.N`. The tag runs `.github/workflows/android-release.yml`: unit tests, lint, signed release APK, emulator smoke test, then a GitHub pre-release with the APK. Install it on the test phone and work through `.github/release-checklist.md`.
*   **Final**: merge the PR, then `python3 scripts/release.py final X.Y.Z` tags `main`. It refuses when `main`'s files differ from the last rc; the workflow then promotes that rc's APK unchanged. Afterwards: delete the rc pre-releases, `release.py cleanup X.Y.Z`, delete the version branch.
*   **Owner runs the tags**: `release.py` pushes tags. Agents run it only with `--dry-run`. The vendored kit (`scripts/release.py`, `scripts/test_release.py`, `.github/pull_request_template.md`) is pinned by `scripts/release.pin`; never edit the copies here, change them in mananutils-platform and vendor again.
*   **Version from the tag**: `versionName = X.Y.Z`, `versionCode = X*10000 + Y*100 + Z` (Y, Z < 100); `RELEASE_TAG` and `GIT_SHA` are in `BuildConfig`. Local builds are `0.0.0-dev`, code 1. Never hand-edit a version in Gradle.
*   **CHANGELOG**: every version adds its entry on the version branch before the rc. It's documentation, no longer a trigger.
*   **Commit Message Convention**: `feat:` for new features, `fix:` for bug fixes, `chore:` for maintenance (CHANGELOG update, dependency bump).

## 5. Build Variants, Signing and Checks

*   **Two package ids**: the debug build is `com.mananpatel.voicebridge.debug` (`applicationIdSuffix`), the release build `com.mananpatel.voicebridge`. They install side by side. The dev loop is `115g vb` (or `./gradlew installDebug`) to the test phone over wireless adb.
*   **Release signing is CI-only**: one PKCS12 keystore (alias `release`), master copy in Vaultwarden; CI reads it from the GitHub environment `android-release` (v* tags only) and checks the certificate against `ANDROID_CERT_SHA256`. Locally `assembleRelease` gives an unsigned APK. A release APK can't be installed over a build signed with another key: uninstall first.
*   **CI gate (every PR, `main`, `v*` branches)**: `.github/workflows/android-ci.yml` runs `testDebugUnitTest lintDebug assembleDebug` without secrets (the API key is empty there) and checks the vendored kit against its pin. Lint errors fail the build (`abortOnError = true`).
*   **Smoke test**: the release workflow installs the signed APK on a KVM emulator, launches it, and fails if it crashed or isn't running after 20 s. What an emulator can't show (microphone, real network, the key's Android restriction) is in `.github/release-checklist.md`, done on the phone before `final`.
*   **API key in a public APK**: the key is restricted to the two packages + certificate SHA-1s and to the STT and Translation APIs, with a per-day quota cap. The restriction only works because every request sends `X-Android-Package` and `X-Android-Cert` (`AndroidClientHeaders.kt`); a new HTTP call to a Google API must use `.androidClient()` too.

## 6. Tooling Conventions

*   **Dry-Run Safety**: Destructive or file-writing operations should be gated behind a check for a `dry_run` flag, printing the intended action to `stdout` instead of executing it.
