# Quickstart: validating App Telemetry (spec 008)

Run on the Chromebook against the OnePlus 11 5G (`115g`). Event fields:
[contracts/telemetry-events.md](contracts/telemetry-events.md).

## Prerequisites (owner, once)

1. PostHog Cloud **US**, two projects: "VoiceBridge debug" and "VoiceBridge".
2. In **both** projects' settings: "Discard client IP data" on; GeoIP transformation off (Data
   pipelines); session replay off; (web) autocapture off.
3. Type both project tokens into `android/local.properties` in the ChromeOS Terminal:
   `POSTHOG_TOKEN_DEBUG=phc_…`, `POSTHOG_TOKEN_RELEASE=phc_…`. They are write-only tokens, but
   keep them out of the repo so forks report nothing.
4. Update the CI secret so release builds report (the secret holds the whole file minus `sdk.dir`):
   `grep -v '^sdk\.dir' android/local.properties | gh secret set LOCAL_PROPERTIES --env android-release -R mananpatel2491/VoiceBridge`
5. Create the dashboards in [contracts/dashboards.md](contracts/dashboards.md) in each project.

## Q1. Nothing private leaves the phone (SC-003)

```bash
cd android && ./gradlew testDebugUnitTest    # TelemetrySchemaTest: allowlist, script characters, exception value strip
```
Then after Q2–Q4, in PostHog → Activity, open 5 events of each type: only the properties of the
contract, no `$locale`/`$timezone`/`$network_carrier`/`$ip`/`$geoip_*`, no exception `value`.
After a week, a SQL insight over `events` finds no row whose properties match `[\x{0900}-\x{097F}\x{0A80}-\x{0AFF}]`.

## Q2. Crash and failure reports (SC-001, SC-005)

1. Debug build has a debug-only "crash test" (long-press on the title). `115g vb`, trigger it,
   reopen the app. Within 5 minutes: an `$exception` in "VoiceBridge debug" with in-app frames in
   `com.mananpatel.voicebridge`, no `value`.
2. Airplane mode, Record, Transcribe: error card as before. Back online: a `stage_failed` with
   `stage=transcribe`, `category=network`.

## Q3. Latency per stage (SC-002)

Read the Amdavadi script 10 times (Record, Stop, Transcribe, Translate). The "Stage latency"
dashboard shows median and p95 of `duration_ms` per `stage` for this `release_tag`.

## Q4. Recognition quality numbers (Story 3)

One clear and one mumbled reading: the mumbled run's `stt_conf_mean` and `stt_conf_min` are
clearly lower and `stt_low_conf_words` higher.

## Q5. No slowdown, and works without the service (SC-004, FR-010)

Compare `duration_ms` of 5 runs with a working token and 5 with an empty one (rebuild): medians
within 50 ms. With PostHog blocked (empty token, or Wi-Fi without internet after a recording),
the app behaves exactly as v0.1.1.

## Q6. Evidence bundle (SC-007, debug only)

```bash
115g evidence        # pulls files/evidence/* and recording.wav into ~/115g-logs/evidence-<time>/
```
Within a minute: `run.json`, `transcript.txt`, `translation.txt`, `words.json`, `recording.wav` of
the last run. For the release APK:
`unzip -p VoiceBridge-*.apk 'classes*.dex' | grep -ac 'transcript.txt'` prints `0` (the release
no-op shares the class name, but has no evidence file names).

## Q7. Volume (SC-006)

After a month: PostHog → Billing shows usage under 10% of the free allowances in both projects.
