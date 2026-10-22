# Data Model: App Telemetry (spec 008)

Wire format: [contracts/telemetry-events.md](contracts/telemetry-events.md).

## PipelineRun (in memory, `MainViewModel`)

| Field | Type | Rule |
|---|---|---|
| `runId` | UUID | New on **Record**; new on **Translate** when there is no current run (typed text). Re-transcribing the same recording keeps the run; a new recording starts a new one |
| `startedAt` | elapsed-realtime ms | for ordering only, never sent |

Lifecycle: `none → recording → recorded → transcribed → translated`; any stage may fail and the
run stays current, so a retry belongs to the same run.

## StageReport → event `stage_completed` / `stage_failed`

| Field | Type | Validation |
|---|---|---|
| `stage` | enum `RECORD, TRANSCRIBE, TRANSLATE` (later `SYNTHESIZE`) | |
| `provider` | enum label | fixed per implementation (`device_mic`, `gcp_stt_v1`, `gcp_translate_v2`) |
| `outcome` | `COMPLETED` / `FAILED` | |
| `durationMs` | Long ≥ 0 | |
| `audioMs`, `bytesSent`, `charsSent` | Long ≥ 0, optional | by stage, see contract |
| `sttQuality` | `SttQuality?` | transcribe only |
| `failure` | `Failure?` | when `FAILED` |

## SttQuality (from the STT response's `words[]`)

| Field | Type | Rule |
|---|---|---|
| `wordCount` | Int | `words.size` |
| `confMean` | Double 0–1 | mean of `confidence`; absent when `wordCount == 0` |
| `confMin` | Double 0–1 | min of `confidence` |
| `lowConfWords` | Int | count with `confidence < 0.6` |
| `phraseHints` | Int | `PHRASE_HINTS.size` |

## Failure

| Field | Type | Rule |
|---|---|---|
| `category` | enum (research R6) | derived from exception type + HTTP status + `error.status` / `details[].reason` |
| `httpStatus` | Int? | |
| `errorReason` | String? | only `^[A-Z][A-Z0-9_]{2,63}$`; otherwise absent |

`SttService` and `TranslationService` return a typed failure (category, status, reason) next to
today's human-readable message; the message still goes to the error card, never to telemetry.

## SttResult (replaces the plain transcript `String`)

`transcript: String`, `words: List<SttWord>` with `word`, `confidence`, `startMs`, `endMs`. Words
go to `SttQuality` (aggregates) and to the evidence bundle (debug builds); never to telemetry.

## EvidenceBundle (debug builds only, `files/evidence/`)

| File | Content |
|---|---|
| `run.json` | `runId`, `releaseTag`, `gitSha`, stage durations, `SttQuality`, failure categories |
| `transcript.txt` | the transcript as returned (UTF-8) |
| `translation.txt` | the translation (UTF-8) |
| `words.json` | `[{word, confidence, startMs, endMs}]` |
| (`files/recording.wav`) | the recording, where it already lives |

Written after each stage; a new run deletes the previous run's files first. Release builds have a
no-op store (`src/release`), so none of these files can exist there.
