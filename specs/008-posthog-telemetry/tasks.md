# Tasks: App Telemetry (crashes, stage latency, error codes)

**Input**: Design documents from `specs/008-posthog-telemetry/`
**Prerequisites**: [plan.md](plan.md), [spec.md](spec.md), [research.md](research.md),
[data-model.md](data-model.md), [contracts/](contracts/), [quickstart.md](quickstart.md)

**Tests**: included where the spec requires them (FR-006 privacy check) and for the pure logic
(research R10). JVM unit tests under `android/app/src/test/`.

Paths are relative to the repo root; `…/voicebridge/` = `android/app/src/main/java/com/mananpatel/voicebridge/`.
Owner tasks (accounts, secrets) are marked **Owner** and need no code.

## Phase 1: Setup

- [ ] T001 Add `implementation("com.posthog:posthog-android:3.72.5")` and `testImplementation("junit:junit:4.13.2")` to `android/app/build.gradle.kts`; add `buildConfigField("String", "POSTHOG_TOKEN", …)` per build type from `local.properties` keys `POSTHOG_TOKEN_DEBUG` (debug) and `POSTHOG_TOKEN_RELEASE` (release), empty default (research R3, FR-011)
- [ ] T002 [P] Document `POSTHOG_TOKEN_DEBUG` / `POSTHOG_TOKEN_RELEASE` (write-only `phc_` tokens, kept out of the repo so forks send nothing) in `android/local.properties.template`
- [ ] T003 Create `…/voicebridge/VoiceBridgeApp.kt` (`Application` subclass, holds the `Telemetry` and `EvidenceStore` instances) and register it with `android:name=".VoiceBridgeApp"` in `android/app/src/main/AndroidManifest.xml`
- [ ] T004 **Owner**: create PostHog Cloud US projects "VoiceBridge debug" and "VoiceBridge"; in both: "Discard client IP data" on, GeoIP transformation off, session replay off; type both tokens into `android/local.properties` (quickstart prerequisites 1–3)

## Phase 2: Foundational (blocks all stories)

- [ ] T005 Create `…/voicebridge/telemetry/Telemetry.kt`: interface `Telemetry { fun stageCompleted(report: StageReport); fun stageFailed(report: StageReport) }` and the data types `Stage`, `Provider`, `StageReport`, `SttQuality`, `Failure` from data-model.md
- [ ] T006 [P] Create `…/voicebridge/telemetry/NoOpTelemetry.kt` (does nothing; used when `BuildConfig.POSTHOG_TOKEN` is empty)
- [ ] T007 Create `…/voicebridge/telemetry/TelemetrySchema.kt`: the event and property allowlist of contracts/telemetry-events.md, and `fun sanitize(name: String, props: Map<String, Any?>): Result` that removes unlisted properties, removes `value` from every `$exception_list` entry and drops `$exception_steps`, and rejects (→ `telemetry_rejected`) any event whose string values contain U+0900–U+097F or U+0A80–U+0AFF or whose name is unlisted. Pure Kotlin, no PostHog types
- [ ] T008 [P] Create `android/app/src/test/java/com/mananpatel/voicebridge/telemetry/TelemetrySchemaTest.kt`: unlisted property removed; `$locale $timezone $network_carrier $user_agent $raw_user_agent` removed; exception `value` removed, frames kept; a Gujarati string and a Devanagari string each reject the event; unknown event name rejected; every property in the contract survives (FR-006)
- [ ] T009 Create `…/voicebridge/telemetry/PostHogTelemetry.kt`, the only file importing `com.posthog`: `PostHogAndroidConfig(token, host = "https://us.i.posthog.com")` with `personProfiles = PersonProfiles.NEVER`, `captureApplicationLifecycleEvents = false`, `captureScreenViews = false`, `captureDeepLinks = false`, `sessionReplay = false`, `errorTrackingConfig.autoCapture = true`, `errorTrackingConfig.inAppIncludes += "com.mananpatel.voicebridge"`, `errorTrackingConfig.exceptionSteps.enabled = false`, `addBeforeSend { TelemetrySchema.sanitize(...) }`; register super properties `build_type`, `release_tag`, `git_sha`; map `StageReport` to `stage_completed` / `stage_failed` properties per the contract (research R2, R4)
- [ ] T010 In `…/voicebridge/VoiceBridgeApp.kt`, pick `PostHogTelemetry` when `BuildConfig.POSTHOG_TOKEN` is non-blank, else `NoOpTelemetry`; any setup exception falls back to `NoOpTelemetry` (FR-010)
- [ ] T011 In `…/voicebridge/MainViewModel.kt`, add the `PipelineRun` id rules of data-model.md (new on Record; new on Translate without a current run; re-transcribe keeps it) and inject `Telemetry` (through a ViewModel factory from `VoiceBridgeApp`)

**Checkpoint**: app builds with and without tokens; `testDebugUnitTest` passes; nothing is sent yet beyond SDK crash capture.

## Phase 3: User Story 1 — See crashes and failed calls (P1) 🎯 MVP

**Goal**: every crash and every failed stage reaches the dashboard with stage, category, status code, version and model. **Independent test**: quickstart Q2.

- [ ] T012 [P] [US1] Create `…/voicebridge/telemetry/FailureCategory.kt`: `fun categorize(e: Throwable?, httpStatus: Int?, errorStatus: String?, reasons: List<String>): Failure` with the rules of research R6; `errorReason` only if it matches `^[A-Z][A-Z0-9_]{2,63}$`
- [ ] T013 [P] [US1] Create `android/app/src/test/java/com/mananpatel/voicebridge/telemetry/FailureCategoryTest.kt`: one case per row of research R6 (incl. 403 `API_KEY_ANDROID_APP_BLOCKED` → `blocked_key`, 429 → `quota`, `IOException` → `network`, 5xx → `server`), and a reason with spaces or lowercase dropped
- [ ] T014 [US1] In `…/voicebridge/SttService.kt`, on failure throw a `StageException(message, failure: Failure)` built with `categorize()` from the HTTP status and the response's `error.status` / `error.details[].reason` (parsed with `JSONObject`, message text never used for the category); empty results → `no_speech`; empty recording → `bad_audio`; blank key → `no_key`. The user-facing message stays as today
- [ ] T015 [P] [US1] Same for `…/voicebridge/TranslationService.kt`
- [ ] T016 [US1] In `…/voicebridge/MainViewModel.kt`, on each failed stage call `telemetry.stageFailed(...)` with run id, stage, provider, `duration_ms`, and the `Failure` from `StageException` (or `categorize(e, null, null, emptyList())` for other exceptions); the error card is unchanged
- [ ] T017 [P] [US1] Create `android/app/src/debug/java/com/mananpatel/voicebridge/telemetry/DebugTools.kt` (`fun crashTest(): Nothing = throw IllegalStateException("VoiceBridge crash test")`) and `android/app/src/release/java/com/mananpatel/voicebridge/telemetry/DebugTools.kt` (no-op)
- [ ] T018 [US1] In `…/voicebridge/MainActivity.kt`, a long-press on the title calls `DebugTools.crashTest()` (does nothing in release)
- [ ] T019 [US1] Run quickstart Q2 on the 11 5G (`115g vb`): crash and airplane-mode failure both visible in "VoiceBridge debug", exception without `value`

**Checkpoint**: MVP: failures and crashes are visible.

## Phase 4: User Story 2 — Measure each stage's latency (P2)

**Goal**: `stage_completed` with `duration_ms` and size numbers for every stage. **Independent test**: quickstart Q3 and Q5.

- [ ] T020 [US2] In `…/voicebridge/AudioRecorder.kt`, make the "recording is ready" moment observable (e.g. `stop()` returns a `Deferred`/callback completed after the WAV header is written) without cancelling the recording coroutine (PATTERNS audio rule); report audio length from the data-chunk size
- [ ] T021 [US2] In `…/voicebridge/MainViewModel.kt`, time each stage with `SystemClock.elapsedRealtime()` (record: Stop → ready; transcribe/translate: tap → result) and call `telemetry.stageCompleted(...)` with `audio_ms`, `bytes_sent`, `chars_sent`, `provider`, and `input_source` for translate (FR-003)
- [ ] T022 [US2] Run quickstart Q3 (10 runs, median/p95 per stage) and Q5 (token vs no token, < 50 ms; service blocked → app unchanged)

## Phase 5: User Story 3 — Tell recognition errors from translation errors (P3)

**Goal**: confidence numbers per transcription, never words. **Independent test**: quickstart Q4. Depends on T021.

- [ ] T023 [US3] In `…/voicebridge/SttService.kt`, add `enableWordConfidence: true` and `enableWordTimeOffsets: true` to the request config and return `SttResult(transcript, words: List<SttWord>)` instead of `String` (research R5); update `…/voicebridge/MainViewModel.kt` to use `.transcript`
- [ ] T024 [US3] Add `fun SttQuality.Companion.from(words: List<SttWord>, phraseHints: Int)` in `…/voicebridge/telemetry/Telemetry.kt` (mean, min, count < 0.6; mean/min absent for no words)
- [ ] T025 [P] [US3] Create `android/app/src/test/java/com/mananpatel/voicebridge/telemetry/SttQualityTest.kt`: empty list, one word, the 0.6 boundary, mean/min of a known list
- [ ] T026 [US3] In `…/voicebridge/MainViewModel.kt`, attach `SttQuality` to the transcribe `stage_completed` (`stt_word_count`, `stt_conf_mean`, `stt_conf_min`, `stt_low_conf_words`, `stt_phrase_hints`)
- [ ] T027 [US3] Run quickstart Q4 (clear vs mumbled reading)

## Phase 6: User Story 4 — Local evidence (P3, debug builds only)

**Goal**: the last run's recording, transcript, translation and word confidences on the phone, pulled with one command. **Independent test**: quickstart Q6. Depends on T023 (words).

- [ ] T028 [P] [US4] Create `…/voicebridge/telemetry/EvidenceStore.kt` (interface: `startRun(runId)`, `recordStage(...)`, `transcript(text, words)`, `translation(text)`)
- [ ] T029 [P] [US4] Create `android/app/src/debug/java/com/mananpatel/voicebridge/telemetry/FileEvidenceStore.kt`: writes `files/evidence/run.json`, `transcript.txt`, `translation.txt`, `words.json` (UTF-8); `startRun` deletes the previous run's files
- [ ] T030 [P] [US4] Create `android/app/src/release/java/com/mananpatel/voicebridge/telemetry/FileEvidenceStore.kt` with the same class name and no file I/O and no evidence file names
- [ ] T031 [US4] In `…/voicebridge/MainViewModel.kt`, feed the `EvidenceStore` from `VoiceBridgeApp` after each stage
- [ ] T032 [US4] Add `115g evidence` to `~/bin/115g` (outside the repo): `run-as com.mananpatel.voicebridge.debug` tar of `files/evidence` + `files/recording.wav` into `~/115g-logs/evidence-<time>/`
- [ ] T033 [US4] Run quickstart Q6, including the release-APK check (`grep -ac 'transcript.txt'` = 0)

## Phase 7: Polish & cross-cutting

- [ ] T034 **Owner**: create the dashboards of contracts/dashboards.md in both projects
- [ ] T035 **Owner**: refresh the CI secret with the release token: `grep -v '^sdk\.dir' android/local.properties | gh secret set LOCAL_PROPERTIES --env android-release -R mananpatel2491/VoiceBridge`
- [ ] T036 [P] Docs: PATTERNS.md (telemetry allowlist, failure categories, debug/release source sets), Project_Structure.md (map rows + changelog for every new file; latency budget section points at the dashboard), Function_Mapping.md, README.md (what is and isn't sent; how to turn it off: no token), CLAUDE.md (new code must go through `Telemetry`, schema changes update the contract + `TelemetrySchema.kt`), CHANGELOG.md `[0.2.0]`
- [ ] T037 [P] Add to `.github/release-checklist.md`: after Transcribe, a `stage_completed` for this tag appears in the "VoiceBridge" project
- [ ] T038 Run `.venv/bin/python scripts/verify_structure.py` and `cd android && ./gradlew testDebugUnitTest lintDebug assembleDebug lintRelease assembleRelease`; open the v0.2.0 PR (merge only after the rc passes)
- [ ] T039 One week after release: quickstart Q1's stored-event inspection and Q7's volume check (SC-003, SC-006)

## Dependencies

- Phase 1 → Phase 2 → stories. T004 (owner) is needed before any on-phone check (T019 onward), not for coding.
- US1 (T012–T019) and US2 (T020–T022) are independent of each other.
- US3 needs US2's `stage_completed` (T021). US4 needs US3's `SttResult` (T023).
- Polish after the stories it documents; T035 before the v0.2.0 rc.

## Parallel examples

- Phase 2: T006 and T008 next to T007/T009 (different files).
- US1: T012 + T013 + T015 + T017 together; then T014, T016, T018.
- US4: T028 + T029 + T030 together; then T031.

## Implementation strategy

1. **MVP**: Phases 1–3. Crashes and failures from the family's phones become visible; ship as
   v0.2.0 if Stories 2–4 need more time.
2. Add US2 (latency), then US3 (confidence); each is checked on the phone before the next.
3. US4 (evidence) last; it only touches the debug build.
4. One version branch (`v0.2.0`), one PR, rc on the phone with the checklist, then `final`.
