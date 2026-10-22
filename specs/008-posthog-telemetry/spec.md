# Feature Specification: App Telemetry (crashes, stage latency, error codes)

**Feature Branch**: `v0.2.0`

**Created**: 2026-10-21

**Status**: Draft

**Input**: User description: "App telemetry for VoiceBridge with PostHog: crash reports, per-pipeline-stage latency (record, STT, translate; later TTS), and error codes, so STT errors can be told apart from translation errors and Chunk 4's latency budget can be measured. Privacy is a hard rule: no audio, transcripts or translations leave the phone; session replay and logcat capture off; IP capture and person profiles off; only numbers and codes are sent. Optional local "debug evidence" mode keeps the last recording, transcript, translation and word confidences on the phone for pulling over adb. Debug and release builds report separately (or carry a build-type property). PostHog Cloud free tier, not self-hosted; the project token is safe in the public repo. Feature flags may later switch Chunk 3 TTS providers."

## Why

On 2026-10-21 the owner was "80% happy" with a translation and couldn't tell whether the
problem was the speech recognition, the translation, or his own pronunciation. Finding out
took a manual session: pulling the recording off the phone over adb, re-running speech
recognition with word confidences, and translating a perfect transcript for comparison. Crashes
and failed calls on the family's phones are invisible today: nothing leaves the phone, and the
system log on the phone is overwritten within hours. Chunk 4 (real-time relay) depends on a
latency budget per stage that has never been measured.

This feature makes those questions answerable from a dashboard, while the app's one hard rule
stays intact: the family's words and voices never leave the phone.

## Clarifications

### Session 2026-10-21

- Q: Data region? → A: US.
- Q: How are debug and release reports kept apart? → A: Two separate telemetry projects, one token each.
- Q: Where is evidence mode available? → A: Debug builds only.
- Q: Is evidence mode switched on and off in debug builds? → A: Always on in debug builds, no switch; only the last run is kept.
- Q: What does the record stage measure? → A: Audio length, and the time from Stop until the recording is ready (not the speaking time).

## User Scenarios & Testing *(mandatory)*

### User Story 1 - See crashes and failed calls (Priority: P1)

The owner opens the telemetry dashboard and sees every crash and every failed recording,
transcription or translation from any of the family's phones: when it happened, which stage
failed, what kind of failure it was (no network, key blocked, daily quota reached, empty or bad
audio, no speech detected, server error), the service's status code, the app version and the
phone model. A crash shows the code location where it happened.

**Why this priority**: Today a failure on a grandparent's phone is only known if someone
mentions it, and the cause is lost by the time the phone reaches the Chromebook. This is the
smallest slice that turns "it didn't work" into a fixable report.

**Independent Test**: In a debug build, trigger a crash on purpose and a failed transcription
(airplane mode); both appear on the dashboard with stage, category, version and model, and no
words from the recording or screen.

**Acceptance Scenarios**:

1. **Given** the phone is online, **When** the app crashes, **Then** a crash report with the code
   location, app version and phone model appears on the dashboard within 5 minutes of the next app
   start.
2. **Given** the API key's daily quota is used up, **When** the user taps Transcribe, **Then** the
   app shows its error card as today, and the dashboard shows a transcription failure of category
   "quota" with the service's status code.
3. **Given** the phone is offline, **When** a transcription fails, **Then** the report is kept on
   the phone and appears on the dashboard after the phone is back online.

---

### User Story 2 - Measure each stage's latency (Priority: P2)

Every completed recording, transcription and translation reports how long it took, together
with the numbers that explain the time: length of the audio, size of what was sent, number of
characters translated. The owner sees the typical (median) and slow-case (95th percentile)
duration of each stage, per app version, and can compare versions.

**Why this priority**: Chunk 4's real-time relay needs a measured latency budget per stage, and
Chunk 3 will add a voice-synthesis stage whose providers must be compared on speed. Without
numbers, both are guesses.

**Independent Test**: Run the 48-second Amdavadi test script 10 times on the test phone; the
dashboard shows median and 95th-percentile durations for recording, transcription and
translation for that version.

**Acceptance Scenarios**:

1. **Given** a transcription succeeds, **When** the dashboard is opened, **Then** that run's
   transcription duration and audio length are visible, and the stage's median and 95th
   percentile update.
2. **Given** two app versions have each been used at least 20 times, **When** the owner compares
   them, **Then** each stage's median and 95th-percentile durations are shown side by side.

---

### User Story 3 - Tell speech-recognition errors from translation errors (Priority: P3)

For each transcription the app reports quality numbers from the recognizer, never the words:
how many words were recognized, the average and lowest word confidence, and how many words
fell below a low-confidence threshold. When a translation looks wrong, the owner can see whether
the transcription that fed it was confident or shaky.

**Why this priority**: This answers the 2026-10-21 question ("is it the translation or my
speech?") for every run, without a manual adb session. It builds on Story 2's per-run reports.

**Independent Test**: Record the test script once clearly and once mumbled; the dashboard shows
clearly lower confidence numbers for the mumbled run.

**Acceptance Scenarios**:

1. **Given** a transcription succeeds, **When** the owner opens that run, **Then** word count,
   average and lowest confidence, and the low-confidence word count are shown, and no word itself.

---

### User Story 4 - Local evidence for a deep look (Priority: P3)

When the numbers aren't enough, the owner reproduces the run on a debug build and pulls the
evidence of the last run off the phone over adb: the recording, the transcript, the translation and the per-word confidences. The
evidence stays on the phone and is never uploaded.

**Why this priority**: The numbers in Story 3 point at a bad run; the evidence explains it (as
the manual analysis did: "માણેક ચોક" heard as "માણસ"). It's only needed occasionally, by the owner.

**Independent Test**: On a debug build, transcribe and translate once, then pull the
evidence with one command on the Chromebook and see all four items for that run.

**Acceptance Scenarios**:

1. **Given** a debug build, **When** a run completes, **Then** the phone holds that run's
   recording, transcript, translation and word confidences, replacing the previous run's.
2. **Given** a release build, **When** any run completes, **Then** no transcript, translation or
   confidence file exists beyond what the app keeps today (the last recording), and no setting can
   create one.

---

### Edge Cases

- The phone is offline for days: reports queue on the phone up to a bounded limit; the oldest are
  dropped first; the app never slows down or fills storage because of telemetry.
- The telemetry service is unreachable or rejects reports: the app works exactly as without
  telemetry; no error card mentions telemetry.
- A build without a telemetry token (pull-request builds, forks of the public repo, a fresh
  clone): telemetry is silently off and nothing is sent.
- A failure message from a Google service quotes part of the request: only the category and status
  code are reported, never the message text.
- The user edits or types Gujarati text and translates it without recording: the translate stage
  is reported with its numbers; the typed text is not.
- A crash's stack trace contains no user data: only code locations and exception types are sent,
  never exception messages that could embed text.
- The app is updated: reports carry the new version, so versions don't mix.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The app MUST report unhandled crashes with the code location (stack trace of class,
  method and line), exception type, app version, build type, phone model and Android version.
- **FR-002**: The app MUST report each failed stage (record, transcribe, translate) with the stage,
  a failure category (network, blocked key, quota, empty or bad audio, no speech, server error,
  other) and the service's status code when there is one.
- **FR-003**: The app MUST report each completed stage with its duration in milliseconds and the
  stage's size numbers. For transcribe and translate the duration is from the tap until the result
  (or failure) is shown; their size numbers are audio length and bytes sent (transcribe) and
  characters sent (translate). The record stage reports the audio length and the time from Stop until
  the recording is ready to play or send; how long the user spoke is not a latency.
- **FR-004**: The app MUST report the recognizer's quality numbers for each successful
  transcription: word count, average word confidence, lowest word confidence, and the number of
  words below 0.6 confidence.
- **FR-005**: The app MUST NOT send audio, transcript text, translation text, typed text,
  individual words, file contents, or the text of any error or exception message. Every report
  MUST consist only of fields from a documented allowlist of numbers, codes and fixed labels.
- **FR-006**: An automated test MUST fail when any report contains a field outside the allowlist,
  or a string value containing Gujarati or Devanagari characters.
- **FR-007**: The app MUST NOT record the screen, upload the device log, store the sender's IP
  address, or build person profiles. Reports MUST be tied only to a random per-install id that
  carries no personal information.
- **FR-008**: Reports MUST be stored by the telemetry service in its US region.
- **FR-009**: Every report MUST carry the app version (release tag and commit) and the build type;
  debug and release builds MUST report to two separate telemetry projects (one token each), so
  test runs never mix with the family's numbers.
- **FR-010**: Reports MUST be sent in the background, queued on the phone while offline (bounded,
  oldest dropped first), and MUST NOT delay any user-visible step by more than 50 ms or change
  any behavior when telemetry fails.
- **FR-011**: A build without a telemetry token MUST compile and run with telemetry off and send
  nothing.
- **FR-012**: Local evidence mode MUST keep the last run's recording, transcript, translation and
  word confidences on the phone, readable over adb, and MUST never upload them. Evidence mode
  MUST exist only in debug builds, where it is always on (no switch); a release build MUST contain no
  way to turn it on and MUST never keep transcript, translation or confidence files.
- **FR-013**: The owner MUST be able to see, without writing queries: the crash list, failures per
  stage and category per day, and median and 95th-percentile duration per stage per version.
- **FR-014**: The report schema (every event and field, its meaning and unit) MUST be documented in
  the repo next to the allowlist, and a schema change MUST update both.
- **FR-015**: The schema MUST allow later stages (voice synthesis in Chunk 3) and a provider label
  per stage to be added without changing existing fields.
- **FR-016**: Expected monthly volume MUST stay within the telemetry service's free tier with at
  least 10× headroom; the plan MUST include the estimate.

### Key Entities

- **Pipeline run**: one pass from recording to translation (or a translation of typed text); has
  a random run id, app version, build type, start time.
- **Stage report**: one stage of a run (record, transcribe, translate; later synthesize): stage,
  outcome, duration, size numbers, quality numbers (transcribe), provider label.
- **Failure report**: a failed stage: stage, category, status code; linked to its run.
- **Crash report**: an unhandled crash: exception type, stack trace (code locations only),
  version, build type, phone model, Android version.
- **Evidence bundle** (debug builds only, on the phone only): the last run's recording, transcript, translation,
  word confidences, and its run id so it can be matched to the dashboard.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: For a failed transcription or translation on the test phone, the owner identifies the
  failing stage and its category from the dashboard alone in under 2 minutes.
- **SC-002**: After 20 runs of a version, the median and 95th-percentile duration of each stage for
  that version are visible on the dashboard.
- **SC-003**: Zero stored reports contain transcript, translation or typed text: the automated
  check passes on every build, and an inspection of one week of stored reports finds no Gujarati or
  Devanagari characters and no field outside the allowlist.
- **SC-004**: With telemetry on, no user-visible step takes more than 50 ms longer than with
  telemetry off, and with the telemetry service blocked the app works exactly as before.
- **SC-005**: A deliberate crash in a debug build appears on the dashboard, with a readable code
  location, within 5 minutes of the next app start.
- **SC-006**: A month of normal family use stays under 10% of the free tier's limits.
- **SC-007**: For a bad run reproduced on a debug build, its evidence bundle is on the Chromebook
  within 1 minute, with one command.

## Assumptions

- The data's consumer is the owner (the developer). The family members are the app's users; the
  app runs on about three phones. No consent dialog: only numbers and codes are sent, and the
  README and the app's About information say so.
- PostHog Cloud is the chosen service (owner's decision of 2026-10-21, after comparing it with
  Firebase Crashlytics and Sentry): free tier, not self-hosted. Its project token can only send
  data in and may be committed to the public repo. Free-tier figures (about 1M events and 100k
  exceptions a month) are re-checked in the plan.
- Session replay, screen capture and device-log capture stay off for good: the app's screens show
  the family's words.
- Release builds aren't minified today, so stack traces are readable without a mapping upload.
  If minification is turned on later, uploading mapping files becomes part of the release
  workflow.
- Telemetry is on in both builds by default, with no in-app switch; turning it off means a build
  without a token.
- Latency is measured on the phone (wall-clock per stage), not on the server.
- Switching voice-synthesis providers with feature flags (Chunk 3) is out of scope; FR-015 only
  keeps the schema open for it.
- The low-confidence threshold of 0.6 comes from the 2026-10-21 analysis, where misheard words
  scored 0.43-0.66.
