# Implementation Plan: App Telemetry (crashes, stage latency, error codes)

**Branch**: `v0.2.0` | **Date**: 2026-10-21 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `specs/008-posthog-telemetry/spec.md`

## Summary

Add PostHog Cloud (US) telemetry behind a `Telemetry` interface: crash reports (SDK
autocapture), and the app's own `stage_completed` / `stage_failed` events carrying per-stage
latency, size numbers, STT confidence aggregates and failure categories. A single `beforeSend`
enforces an allowlist, so only the numbers and labels in
[contracts/telemetry-events.md](contracts/telemetry-events.md) can leave the phone. Debug and
release report to separate projects; a missing token means no telemetry. Debug builds also keep
an evidence bundle of the last run on the phone (code in `src/debug` only). Research:
[research.md](research.md).

## Technical Context

**Language/Version**: Kotlin 2.0.21 (AGP 9.1.1 built-in Kotlin), Java 17 target, Gradle 9.3.1

**Primary Dependencies**: `com.posthog:posthog-android:3.72.5` (new, pinned); existing OkHttp
4.12.0, coroutines 1.9.0, Compose BOM 2024.09.00. Tests: `junit:junit:4.13.2` (new, test only)

**Storage**: PostHog SDK's on-device event queue (max 1,000, oldest dropped); debug-only
evidence files in the app's private `files/evidence/`

**Testing**: JVM unit tests (first in the repo) for allowlist/sanitizer, failure categories, STT
aggregation; CI's `testDebugUnitTest`; on-phone checks in [quickstart.md](quickstart.md)

**Target Platform**: Android 7.0+ (minSdk 24, target 35); test phone OnePlus 11 5G (Android 16)

**Project Type**: mobile app (single Gradle module `:app`)

**Performance Goals**: telemetry adds < 50 ms to any user-visible step (SC-004); crash visible
within 5 min of the next start (SC-005)

**Constraints**: no text, audio or words leave the phone (FR-005); works offline; fails silent;
free tier only

**Scale/Scope**: ~3 phones, ~3,600 events/month (research R9)

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-checked after Phase 1 design.*

| Principle | Check | Result |
|---|---|---|
| I. Context-first architecture map | New files logged in `Project_Structure.md` (map + changelog); `Function_Mapping.md` gets the telemetry calls | Pass (tasks) |
| II. Pattern integrity | New PATTERNS entries: telemetry allowlist, failure categories, debug-only source sets | Pass (tasks) |
| III. Voice pipeline discipline | PostHog only behind `Telemetry` (`PostHogTelemetry` + `NoOpTelemetry`); business logic calls the interface. Audio contract unchanged | Pass |
| IV. Gated validation | No backend API → Bruno n/a. The principle's text still names `smoke-test.ps1`, removed in v0.1.0; corrected here to the CI + release-checklist gate (`.specify/memory/constitution.md`) | Pass after fix |
| V. IaC & cost gating | No GCP change (word confidence is part of the same STT call). PostHog projects are non-GCP SaaS, created by hand (documented in quickstart prerequisites). Cost $0, 250× free-tier headroom (R9) | Pass |
| Operational: audio data leakage | Central to the design: allowlist, script-character rejection, exception message strip, debug-only evidence | Pass |
| Operational: secrets stay local | Tokens in `local.properties` / CI secret, though write-only (R3) | Pass |

Post-design re-check: no violations, nothing in Complexity Tracking.

## Project Structure

### Documentation (this feature)

```text
specs/008-posthog-telemetry/
├── spec.md
├── plan.md                         # this file
├── research.md
├── data-model.md
├── quickstart.md
├── contracts/
│   ├── telemetry-events.md         # event + property allowlist (the privacy contract)
│   └── dashboards.md
├── checklists/requirements.md
└── tasks.md                        # /speckit-tasks
```

### Source Code

```text
android/app/
├── build.gradle.kts                # posthog dep, junit, POSTHOG_TOKEN per build type
└── src/
    ├── main/java/com/mananpatel/voicebridge/
    │   ├── VoiceBridgeApp.kt       # new Application: sets up Telemetry before any Activity
    │   ├── MainViewModel.kt        # run ids, stage timing, reports
    │   ├── SttService.kt           # word confidence/offsets; SttResult; typed failure
    │   ├── TranslationService.kt   # typed failure
    │   ├── AudioRecorder.kt        # "recording ready" signal for the record stage
    │   └── telemetry/
    │       ├── Telemetry.kt        # interface + StageReport, SttQuality, Failure
    │       ├── TelemetrySchema.kt  # allowlist, sanitizer (beforeSend), script check
    │       ├── FailureCategory.kt  # R6 rules
    │       ├── PostHogTelemetry.kt # the only file that imports com.posthog
    │       ├── NoOpTelemetry.kt
    │       └── EvidenceStore.kt    # interface
    ├── debug/java/com/mananpatel/voicebridge/telemetry/
    │   ├── FileEvidenceStore.kt    # writes files/evidence/
    │   └── DebugTools.kt           # crash test (long-press title)
    ├── release/java/com/mananpatel/voicebridge/telemetry/
    │   ├── FileEvidenceStore.kt    # no-op with the same name: release keeps no evidence
    │   └── DebugTools.kt           # no-op
    ├── main/AndroidManifest.xml    # android:name=".VoiceBridgeApp"
    └── test/java/com/mananpatel/voicebridge/telemetry/
        ├── TelemetrySchemaTest.kt
        ├── FailureCategoryTest.kt
        └── SttQualityTest.kt
```

Outside the repo: `~/bin/115g` gets an `evidence` command (pull `files/evidence/` and the recording
of the `.debug` package with `run-as`).

**Structure Decision**: single Android module; telemetry in its own package; debug/release source
sets give the release APK no evidence or crash-test code at all.

## Complexity Tracking

None.
