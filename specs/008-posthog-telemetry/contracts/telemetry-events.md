# Contract: Telemetry events and allowlist

This is the complete list of what VoiceBridge may send. `beforeSend` enforces it (anything not
listed is removed or dropped), and `TelemetrySchemaTest` fails if code tries to send anything
else (FR-005, FR-006, FR-014). A change here needs the same change in `TelemetrySchema.kt`, and
the reverse.

**Never sent, in any field**: audio, transcript, translation, typed text, individual words,
file names or paths, exception messages, server error messages, user names, account ids.

## Properties on every event

| Property | Type | Values / meaning |
|---|---|---|
| `build_type` | label | `debug` or `release` (also implied by the project) |
| `release_tag` | label | `BuildConfig.RELEASE_TAG`: `vX.Y.Z-rc.N`, `vX.Y.Z` or `dev` |
| `git_sha` | label | `BuildConfig.GIT_SHA`: 7 hex characters, or `local` |
| SDK context, kept | label/number | `$app_build $app_name $app_namespace $app_version $device_manufacturer $device_model $device_name $device_type $is_emulator $lib $lib_version $os_name $os_version $screen_density $screen_height $screen_width` |
| SDK internals, kept | — | `distinct_id` (random per install), `$session_id`, `$insert_id`, `uuid`, `timestamp`, `$process_person_profile` (always false) |

Removed from every event: `$locale $timezone $network_carrier $user_agent $raw_user_agent`, and any
other property not listed here.

## `stage_completed`

| Property | Type | Stages | Meaning |
|---|---|---|---|
| `run_id` | UUID | all | links the stages of one run |
| `stage` | label | all | `record`, `transcribe`, `translate` (later `synthesize`) |
| `provider` | label | all | `device_mic`, `gcp_stt_v1`, `gcp_translate_v2` (later TTS providers) |
| `duration_ms` | int ≥ 0 | all | record: Stop → recording ready; transcribe/translate: tap → result shown |
| `audio_ms` | int ≥ 0 | record, transcribe | length of the recording |
| `bytes_sent` | int ≥ 0 | transcribe | PCM bytes uploaded |
| `chars_sent` | int ≥ 0 | translate | characters sent for translation |
| `stt_word_count` | int ≥ 0 | transcribe | words recognized |
| `stt_conf_mean` | float 0–1 | transcribe | average word confidence |
| `stt_conf_min` | float 0–1 | transcribe | lowest word confidence |
| `stt_low_conf_words` | int ≥ 0 | transcribe | words with confidence < 0.6 |
| `stt_phrase_hints` | int ≥ 0 | transcribe | number of `speechContexts` phrases sent |
| `input_source` | label | translate | `transcript` or `typed` (whether the text was edited is not recorded) |

## `stage_failed`

| Property | Type | Meaning |
|---|---|---|
| `run_id`, `stage`, `provider`, `duration_ms` | as above | |
| `category` | label | `network`, `blocked_key`, `quota`, `bad_audio`, `no_speech`, `server`, `no_key`, `other` (research R6) |
| `http_status` | int or absent | the service's HTTP status code |
| `error_reason` | label or absent | Google's machine-readable `error.details[].reason` or `error.status` (e.g. `API_KEY_ANDROID_APP_BLOCKED`, `RESOURCE_EXHAUSTED`); only values matching `^[A-Z][A-Z0-9_]{2,63}$` |

## `$exception` (SDK error tracking)

Kept: `$exception_list[]` entries with `type`, `module`, `mechanism`, `stacktrace.frames[]`
(`module function filename lineno in_app platform`), plus `$exception_level`.
Removed: each entry's `value` (the message), and `$exception_steps`.

## `telemetry_rejected`

Sent instead of an event that broke a rule, so a leak attempt is visible without its content.

| Property | Type | Meaning |
|---|---|---|
| `rejected_event` | label | the event name |
| `reason` | label | `script_characters` (Gujarati/Devanagari found), `unknown_event` |

## Rules for string values

Every string property must be one of: a label from the tables above, a UUID, 7 hex characters,
or an SDK context value. Any string containing a character in U+0900–U+097F or U+0A80–U+0AFF
rejects the whole event (→ `telemetry_rejected`).
