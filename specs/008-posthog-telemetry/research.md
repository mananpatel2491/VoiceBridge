# Research: App Telemetry (spec 008)

All facts checked on 2026-10-21 against PostHog's docs and the source of
`PostHog/posthog-android` at tag `android-v3.72.5` (published 2026-10-20).

## R1. SDK and version

- **Decision**: `com.posthog:posthog-android:3.72.5`, pinned exactly (not `3.+`).
- **Rationale**: the docs' `3.+` would change the SDK under a tagged release; the repo pins every
  dependency. 3.72.5 has `addBeforeSend`, `personProfiles`, error-tracking autocapture and
  `inAppIncludes`. Its transitive OkHttp is 4.12.0, the version the app already uses
  (`com.squareup.okhttp3:okhttp:4.12.0`), so there is no conflict; it adds Gson 2.10.1, okio,
  androidx lifecycle-process and curtains.
- **Alternatives**: Firebase Crashlytics + Performance (two products, no flags, `google-services.json`
  in a public repo); Sentry (best traces, no flags, token less clearly public-safe). Owner chose
  PostHog on 2026-10-21.

## R2. What the SDK sends by itself, and how to stop it

| Source | What | Decision |
|---|---|---|
| Event context (`PostHogAndroidContext`) | `$app_build $app_name $app_namespace $app_version $device_manufacturer $device_model $device_name`(= `Build.DEVICE`, a codename) `$device_type $is_emulator $lib $lib_version $os_name $os_version $screen_density $screen_height $screen_width` | Keep (allowlist) |
| Event context | `$locale $timezone $network_carrier $user_agent $raw_user_agent` | Drop in `beforeSend`: not needed, and they narrow down a person |
| `$exception` (`ThrowableCoercer`) | per exception: `type` (class), `module` (package), `mechanism`, `stacktrace.frames[]` with `module function filename lineno in_app platform`, **and `value` = `throwable.message`** | Keep everything except `value`, which `beforeSend` removes: our messages embed server replies and could embed text (FR-005) |
| `$exception_steps` (breadcrumbs, on by default) | only what the app records with `addExceptionStep` | Disable (`exceptionSteps.enabled = false`): nothing to record |
| Lifecycle, screen views, deep links | `Application Opened/Backgrounded`, `$screen`, deep link URLs | All off (`captureApplicationLifecycleEvents`, `captureScreenViews`, `captureDeepLinks` = false): our own events cover what's needed, and deep link URLs are free text |
| Session replay | off by default (`sessionReplay = false`) | Stays off, never configured. That also keeps `captureLogcat` (a replay option) inert |
| Person profiles | `IDENTIFIED_ONLY` by default | `PersonProfiles.NEVER`; the app never calls `identify()` |
| IP and GeoIP | the server sees the request IP; the SDK has no option for it | Project settings (owner, both projects): "Discard client IP data" on, GeoIP transformation off. Checked in quickstart |

- **Decision**: one `beforeSend` that enforces the allowlist from
  [contracts/telemetry-events.md](contracts/telemetry-events.md): unknown event names are dropped,
  unknown properties removed, exception `value`s removed, and any string with Gujarati
  (U+0A80–U+0AFF) or Devanagari (U+0900–U+097F) characters drops the whole event and counts a
  `telemetry_rejected` event instead (FR-005, FR-006).
- **Rationale**: an allowlist fails closed. A new SDK version that adds a property can't leak it.

## R3. Hosts, projects and tokens

- **Decision**: US Cloud, host `https://us.i.posthog.com` (clarification Q1). Two projects (Q2):
  "VoiceBridge debug" and "VoiceBridge". Their project tokens (`phc_…`) go into
  `android/local.properties` as `POSTHOG_TOKEN_DEBUG` and `POSTHOG_TOKEN_RELEASE`, and into
  `BuildConfig.POSTHOG_TOKEN` per build type. An empty token means telemetry is off (FR-011).
- **Rationale**: the tokens are write-only and safe to publish, but keeping them out of the repo
  means forks and PR builds send nothing, with no extra logic. CI release builds get
  `POSTHOG_TOKEN_RELEASE` through the existing `LOCAL_PROPERTIES` secret.
- **Alternatives**: commit the tokens (rejected: forks would report into the family's project).

## R4. Crash delivery

- **Decision**: `errorTrackingConfig.autoCapture = true`, `inAppIncludes = ["com.mananpatel.voicebridge"]`.
  The SDK wraps the uncaught-exception handler, writes the event to its disk queue, and sends it at
  the next start (SC-005: within 5 minutes of the next app start).
- Release builds aren't minified (`isMinifyEnabled` not set), so frames are readable without a
  mapping upload. If R8 is turned on later, the release workflow must upload mapping files.

## R5. STT quality numbers

- **Decision**: add `enableWordConfidence: true` and `enableWordTimeOffsets: true` to the
  `speech:recognize` config. The response then has `words[]` with `word`, `confidence`,
  `startTime`, `endTime`. Telemetry gets only counts and confidence aggregates; the words go to the
  evidence bundle (debug builds) and nowhere else.
- **Rationale**: used on 2026-10-21 (diagnose.py) with this exact API and key; no price change
  (billing is per audio second).

## R6. Failure categories

From the HTTP status and the error's machine-readable fields (`error.status`,
`error.details[].reason`), never from `error.message`:

| Category | Rule |
|---|---|
| `network` | `IOException` (no connection, timeout, TLS) |
| `blocked_key` | 403 with reason `API_KEY_ANDROID_APP_BLOCKED` or `API_KEY_SERVICE_BLOCKED` |
| `quota` | 429, or status `RESOURCE_EXHAUSTED` |
| `bad_audio` | the app's own "recording is empty or too short", or 400 `INVALID_ARGUMENT` from STT |
| `no_speech` | STT 200 with no results |
| `server` | 5xx |
| `no_key` | key blank in `BuildConfig` |
| `other` | anything else |

## R7. Evidence bundle (debug only)

- **Decision**: an `EvidenceStore` interface; the real implementation lives in `src/debug/java`,
  a no-op in `src/release/java`. So the release APK contains no evidence code at all (Q3, FR-012).
  Files in the app's private `files/evidence/`: `run.json` (run id, version, timings),
  `transcript.txt`, `translation.txt`, `words.json`; the recording stays at `files/recording.wav`.
  Each run replaces the previous one. Pulled with `adb exec-out run-as com.mananpatel.voicebridge.debug …`
  (debug builds are debuggable), wrapped in a new `115g evidence` command.
- **Alternatives**: a build-config flag checked at runtime (rejected: the code would still ship in
  release).

## R8. Latency measurement

- **Decision**: `SystemClock.elapsedRealtime()` in the ViewModel around each stage: transcribe and
  translate from the tap until the result or failure is shown; record from Stop until
  `AudioRecorder` has finalized the WAV header (FR-003, clarification).
- **Overhead**: `PostHog.capture` only queues; sending is on the SDK's executor, so the UI path adds
  well under 50 ms (SC-004; measured in quickstart Q5).

## R9. Volume and cost (FR-016, constitution V)

About 3 phones × ~10 runs/day × ~4 events/run ≈ 3,600 events/month, plus rare exceptions. Free tier
(PostHog FAQ, to re-check at sign-up): 1M events and 100k exceptions per month. That's about 0.4%
of the event allowance: 250× headroom. Cost: $0. No GCP change: word confidence is part of the same
`speech:recognize` call.

## R10. Unit tests

- **Decision**: the repo's first JVM unit tests (JUnit 4, `testImplementation`), for the parts that
  are pure logic: the allowlist and Gujarati/Devanagari check, the exception-value strip, failure
  categorization, and STT-response aggregation. CI's `testDebugUnitTest` already runs them.
