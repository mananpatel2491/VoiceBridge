---
name: voicebridge-architecture-contract
description: >-
  The VoiceBridge architecture contract — the load-bearing design decisions, WHY each
  was made, the invariants that must hold, and the honestly-stated weak points. Load
  this skill BEFORE designing, extending, or refactoring anything in the VoiceBridge
  app or pipeline: adding a pipeline stage (TTS, LLM, relay), changing audio formats
  or sample rates, touching MainViewModel state, swapping a cloud provider, extracting
  the provider interfaces, planning Chunk 3 or Chunk 4, or answering "why is X built
  this way?" / "can I change Y without breaking Z?". Also load it when reviewing a
  proposed change for architectural fit. Do NOT load it for step-by-step
  build/run/release mechanics (use voicebridge-build-and-env or
  voicebridge-release-gate-runbook), for debugging a live failure
  (voicebridge-debugging-playbook), for GCP API request/response details
  (voicebridge-gcp-speech-apis-reference), or for byte-level WAV/PCM mechanics
  (voicebridge-audio-pipeline-reference) — this skill is the WHY and the MUST-HOLD,
  not the HOW.
---

# VoiceBridge Architecture Contract

This is the design constitution's engineering companion. It records the decisions that hold the
project together, why they were made, and exactly where the codebase falls short of its own
documentation. Read it before you design anything. When this file conflicts with `GEMINI.md`
(repo root), **GEMINI.md wins** — that is the project's constitution of record.

**What VoiceBridge is:** a personal Android app (Kotlin + Jetpack Compose, app id
`com.mananpatel.voicebridge`, `minSdk 24`) that bridges Gujarati-speaking grandparents and an
English-speaking 4-year-old on WhatsApp video calls. Full vision: record → STT → translate →
voice-clone TTS → playback, eventually as a real-time two-phone relay. There is **no backend**
today — the app calls GCP REST APIs directly from the device.

## Glossary (defined once, used throughout)

| Term | Meaning |
| :--- | :--- |
| **Chunk** | A shippable delivery stage of the product vision (Chunk 0–4). Not a Scrum sprint — each chunk is a working end-to-end capability. |
| **STT / TTS** | Speech-to-Text / Text-to-Speech. |
| **PCM 16-bit** | Raw uncompressed audio samples, 2 bytes each, little-endian. |
| **LINEAR16** | GCP's name for raw PCM 16-bit audio (no container, no compression). |
| **WAV header** | The 44-byte RIFF header that wraps raw PCM so `MediaPlayer` can play the file. |
| **VAD** | Voice Activity Detection — detecting speech vs. silence so silence is never sent to a paid API. |
| **Provider interface** | An abstraction (e.g. `STTProvider`) behind which a concrete vendor implementation is injected, per `PATTERNS.md` §2. |
| **Spec Kit** | GitHub Spec Kit: durable `specs/NNN-*/` artifacts (spec/plan/tasks) required for any non-trivial feature (`GEMINI.md` "Spec-Driven Feature Workflow"). |
| **Release gate** | The post-commit-hook-driven smoke test + auto-merge flow on `vX.Y.Z` branches (see voicebridge-release-gate-runbook). |
| **GIST debt** | Uncertainty-driven technical debt from re-litigating already-decided questions — the thing `PATTERNS.md` exists to prevent. |

## When NOT to use this skill

| You need... | Use instead |
| :--- | :--- |
| Version-branch / CHANGELOG / hook discipline, doc-update obligations | voicebridge-change-control |
| Run the release gate, smoke test flags, auto-merge mechanics | voicebridge-release-gate-runbook |
| JDK/SDK/Gradle setup, build commands, emulator bring-up | voicebridge-build-and-env |
| Diagnose a live crash, failed smoke run, API error | voicebridge-debugging-playbook |
| Past incidents and their root causes (v0.0.5 merge bypass, 88ac97a) | voicebridge-failure-archaeology |
| WAV byte layout, AudioRecord buffer mechanics, header math | voicebridge-audio-pipeline-reference |
| GCP STT/Translation request/response shapes, quotas, error codes | voicebridge-gcp-speech-apis-reference |
| Where flags/keys live and how they're injected | voicebridge-config-and-flags |
| adb/uiautomator/logcat tooling | voicebridge-diagnostics-and-tooling |
| Test strategy and QA checklists | voicebridge-validation-and-qa |
| Writing/updating the governance docs themselves | voicebridge-docs-and-writing |
| Building Chunk 3 (voice-clone TTS) | voicebridge-chunk3-voice-clone-tts-campaign |
| Evaluating new/unproven tech options | voicebridge-research-frontier |

---

## 1. The chunked delivery model

The product ships in strictly ordered chunks. Each chunk is independently demonstrable and
smoke-testable. Never build chunk N+1 features inside a chunk-N change (`README.md:69–75` is the
status table of record).

| Chunk | Delivers | Status (2026-07-13) | Shipped in |
| :---- | :------- | :------------------ | :--------- |
| 0 | Mic permission, record/stop/play WAV | ✅ Built | v0.0.2 |
| 1 | Gujarati STT via GCP (`gu-IN`) | ✅ Built | v0.0.2 |
| 2 | Gujarati→English text translation | ✅ Built | v0.0.4 |
| 3 | Voice-clone TTS (speaker's voice preserved) | **Not started** | — |
| 4 | Real-time pipeline + two-phone acoustic relay | **Not started** | — |

**Why chunks:** each stage de-risks the next. Chunk 0 proved raw PCM capture; Chunk 1 proved the
audio contract is GCP-compatible; Chunk 2 proved credential reuse. Chunk 4's latency demands
shaped decisions made back in Chunk 0 (see §3 and §4) — the chunks are sequential but the
architecture was designed backwards from Chunk 4.

Interleaved with app chunks: v0.0.3 (release gate), v0.0.5 (Spec Kit adoption), v0.0.6
(retro-specs 001–005), v0.0.7 (docs drift fixes) — framework releases, not app chunks.

## 2. Pipeline Stage Registry — and the honest gap

`Project_Structure.md:50–59` defines the canonical pipeline:

Audio Capture → STT → Translation → LLM (TBD) → TTS (TBD) → Audio Output

Every stage names a provider interface (`AudioCapture`, `STTProvider`, `TranslationProvider`,
`LLMProvider`, `TTSProvider`, `AudioOutput`), because `PATTERNS.md:20` (Provider Interface
Pattern) mandates: *never call a vendor SDK directly from business logic*.

**THE GAP, stated plainly: none of these interfaces exist in code.** As of 2026-07-13:

- `SttService` and `TranslationService` are Kotlin `object` singletons (`SttService.kt:26`,
  `TranslationService.kt:12`) called **directly** from `MainViewModel` (`MainViewModel.kt:90`,
  `MainViewModel.kt:131`).
- `AudioRecorder`/`AudioPlayer` are concrete classes instantiated directly in `MainViewModel`
  (`MainViewModel.kt:29–30`).
- Extraction is tracked as genuinely-open tasks: `specs/003-gujarati-stt/tasks.md` T012
  (`STTProvider`), `specs/004-gujarati-english-translation/tasks.md` T012
  (`TranslationProvider`), `specs/002-voice-capture-playback/tasks.md` T015
  (`AudioCapture`/`AudioOutput`).

**What this means for you:** the registry's "Provider Interface" column is a *commitment*, not a
description. When you add TTS (Chunk 3), do NOT copy the current pattern (direct object call) —
that would deepen the debt. Either extract the interface for your new stage from day one, or
extract `STTProvider`/`TranslationProvider` first and follow suit. The registry column names are
the agreed interface names — use them verbatim.

## 3. The audio format contract

**Contract:** all audio between pipeline stages is **PCM 16-bit, 16 kHz, mono**, stored as WAV
with a 44-byte header. Exceptions require documented rationale in `PATTERNS.md` (`PATTERNS.md:23`).

Where it lives in code:

| Fact | Location |
| :--- | :--- |
| `SAMPLE_RATE = 16_000`, mono, `ENCODING_PCM_16BIT` | `AudioRecorder.kt:29–31` |
| 44-byte header written after recording stops (sizes back-filled) | `AudioRecorder.kt:88–95` |
| Header **stripped** before upload; raw PCM base64'd | `SttService.kt:45–46` |
| Declared to GCP as `encoding: LINEAR16`, `sampleRateHertz` from `AudioRecorder.SAMPLE_RATE` | `SttService.kt:50–51` |
| WAV header size constant duplicated as `WAV_HEADER_BYTES = 44` | `SttService.kt:29` |

**Why this exact format (README.md:37–42):**
- `AudioRecord` produces raw PCM natively — WAV is just a 44-byte wrapper, zero transcoding.
- GCP STT accepts it as LINEAR16 with **no conversion step** on device.
- Chunk 4's real-time pipeline will stream the **same PCM buffers** — no format migration later.
- M4A/AAC was explicitly ruled out (GCP STT would need a decode step).

The whole point is **zero conversion across three consumers**: `AudioRecord` (capture),
GCP STT (upload), and the future Chunk-4 streaming path. Changing sample rate, bit depth, or
channel count breaks all three simultaneously and silently (GCP will mis-decode mismatched
declared vs. actual rates rather than erroring).

Note the duplication hazard: header size and sample rate appear in both `AudioRecorder.kt` and
`SttService.kt` (`SttService` at least reads `AudioRecorder.SAMPLE_RATE`; the 44 is duplicated
as two constants). If you touch the WAV writer, grep for `44` and `WAV_HEADER` across the app.

## 4. Framework choice: Kotlin native + Jetpack Compose

Chosen over Flutter and React Native (`README.md:22–27`) because:

- **Raw PCM access**: `AudioRecord`/`AudioTrack` give direct byte-buffer control, zero JNI
  overhead — a hard requirement for Chunk 4's real-time relay.
- **No bridge latency**: Flutter/RN add a platform-channel hop on every audio buffer;
  unacceptable for near-real-time voice.
- Compose gives declarative UI without XML.

Similarly deliberate vendor choices: GCP STT v1 over Whisper (explicit `gu-IN` acoustic model,
plain REST, free tier 60 min/mo — `README.md:29–35`); GCP Translation v2 over DeepL (no Gujarati),
Azure (separate account), OpenAI (cost/indirection) — decisive factor was **credential reuse**
(`README.md:11–20`). Do not re-litigate these without new evidence (that is GIST debt).

Toolchain of record: AGP 9.1.1 with **built-in Kotlin** (2.0.21; no standalone
`org.jetbrains.kotlin.android` plugin since v0.0.8 — re-adding it breaks configuration,
see voicebridge-failure-archaeology INC-6), Gradle 9.3.1 wrapper **committed**.

## 5. Single-key credential design

One API key, `GCP_STT_API_KEY`, covers **both** STT and Translation — same GCP project, both APIs
enabled (`README.md:126`). The name is historical (created for Chunk 1 STT); it was deliberately
reused rather than renamed when Chunk 2 arrived.

Flow: gitignored `android/local.properties` → `buildConfigField` in
`android/app/build.gradle.kts:27–30` → `BuildConfig.GCP_STT_API_KEY` read once in
`MainActivity.kt:32` and passed down as a plain `String` parameter.

Rules:
- The key is **never committed** (`android/.gitignore` excludes `local.properties`;
  `local.properties.template` documents the required entries).
- Services receive the key as a function argument (`SttService.kt:36`,
  `TranslationService.kt:21`) — they never read config themselves. Keep it that way; it is what
  makes the future provider-interface extraction trivial.
- A blank key is a *handled state*, not a crash: `MainViewModel.kt:74–79` and
  `TranslationService.kt:24–30` produce human-readable error messages pointing at
  `local.properties.template`. The smoke test depends on this (see §7).

When Chunk 3 adds a TTS vendor outside GCP, that vendor gets its **own** key entry following the
same `local.properties → buildConfigField` pattern — do not overload `GCP_STT_API_KEY`.

## 6. The state machine (`MainViewModel.kt`)

All UI state is one immutable `UiState` data class in a `MutableStateFlow`
(`MainViewModel.kt:13–22, 26–27`), mutated only via `_uiState.update { it.copy(...) }`:

| Field | Meaning |
| :--- | :--- |
| `recordingState` | `RecordingState` enum: `IDLE → RECORDING → STOPPED` (`MainViewModel.kt:11`) |
| `hasRecording` | Gates Play/Transcribe buttons; set on first stop |
| `isTranscribing` / `isTranslating` | In-flight flags; mutually exclusive via button `enabled` logic in `MainActivity.kt:131–136, 168–172` |
| `transcript` | Editable — filled by STT **or typed by hand** (lets you test translation without speaking) |
| `translatedText` | Rendered as a card only when non-empty (`MainActivity.kt:187`) |
| `statusMessage` | Always-visible one-liner |
| `errorMessage` | Nullable; non-null renders the error card (`MainActivity.kt:93–106`) |

**Load-bearing behaviors — preserve these when refactoring:**

1. **Stale-translation clearing**: editing the transcript field clears `translatedText`
   (`onTranscriptEdited`, `MainViewModel.kt:113–117`) so a translation of *old* text never sits
   under *new* text. Starting a new recording clears both transcript and translation
   (`MainViewModel.kt:39–40`); starting a transcription clears both too (`MainViewModel.kt:83–84`).
   Any new derived-output stage (TTS audio in Chunk 3!) must follow the same rule: **when the
   input changes, derived output is cleared, not left stale**.
2. **Single recording file**: `File(filesDir, "recording.wav")` created once in
   `MainActivity.kt:26` and threaded through as a parameter. Each recording overwrites it.
3. **Cleanup on ViewModel death**: `onCleared()` stops recorder and player
   (`MainViewModel.kt:154–158`).
4. `AudioRecorder.stop()` deliberately does **not** cancel the writer coroutine — the coroutine
   must finish back-filling the WAV header (`AudioRecorder.kt:80–86`). Don't "fix" that.

**Honest limits:** the ViewModel survives rotation (that's why it's a ViewModel), but nothing is
persisted for **process death** — `hasRecording`, transcript, and translation all vanish even
though `recording.wav` survives on disk. There is no `SavedStateHandle`. Rotation and
process-death paths are also untested (`specs/005-release-gate-automation/tasks.md` T016).

## 7. Error-surfacing philosophy — smoke-test-enforced

The contract: **service failures become `Result.failure` with a human-readable message; the UI
renders an error card; the app never crashes on a failed call.**

- Both services wrap everything in `runCatching` inside `withContext(Dispatchers.IO)` and return
  `Result<String>` (`SttService.kt:36–38`, `TranslationService.kt:21–23`). They extract GCP's own
  error message from the response body when available (`SttService.kt:69–75`,
  `TranslationService.kt:48–55`).
- The caller (`MainViewModel`) `fold`s the Result into `errorMessage` state; `MainActivity`
  renders any non-null `errorMessage` as a Material error card (`MainActivity.kt:93–106`).
- "No speech detected" is a **success** with a placeholder, not an error
  (`SttService.kt:78–81`, `MainViewModel.kt:95`).

This is not just style — it is **enforced by the release gate**: the smoke test taps Transcribe
without a real API key and asserts an error card appears rather than a crash
(`PATTERNS.md:45`, "Transcribe Without a Key"), and logcat is scanned for `FATAL EXCEPTION`
after every UI step (`PATTERNS.md:44`). If you break the error card, releases stop merging.

Corollary: keep button/label strings in sync with the smoke test's text-based selectors
(`PATTERNS.md:42`) — renaming "Transcribe (Gujarati)" without updating
`android/scripts/smoke-test.ps1` fails the gate.

## 8. Mandated but NOT yet implemented (do not describe as existing)

These principles are constitutional (`GEMINI.md:41–45`, `PATTERNS.md` §2) and **binding on new
work**, but the current code does not satisfy them. Label them "open" in anything you write:

| Mandate | Source | Reality (2026-07-13) | Tracking |
| :--- | :--- | :--- | :--- |
| Provider interfaces per stage | `PATTERNS.md:20` | Registry documents names; zero interfaces in code (§2) | specs 002/T015, 003/T012, 004/T012 |
| Streaming-first (all stages expose streaming; buffered only if changelog-marked batch) | `PATTERNS.md:21`, `GEMINI.md:42–43` | Everything is single-shot buffered REST; `speech:recognize` has ~1 min audio ceiling | specs 002/T014, 003/T013 |
| VAD gating of paid STT calls | `PATTERNS.md:22` | No VAD anywhere; silence is uploaded and billed | specs 002/T013, 003/T014 |
| Latency budget rows (P50/P95 per hop) in `Project_Structure.md` | `PATTERNS.md:24` | No latency rows exist | specs 002/T016, 003/T015, 004/T015 |
| Async-first with `asyncio` | `PATTERNS.md:29` | Written for a Python backend that doesn't exist; the Kotlin analogue (coroutines + `Dispatchers.IO`) IS satisfied | — |

Chunk 4 cannot ship without the first three. Treat any Chunk-3/4 plan that skips them as
architecturally non-conforming.

## 9. Known-weak points (stated plainly)

1. **Happy-path-only smoke coverage** — the gate drives Record→Stop→Play→Transcribe→Translate
   once; no rotation, process-death, permission-revocation, or airplane-mode steps
   (specs/005 T016). A pass means "the demo works", not "the app is robust".
2. **Brittle result detection** — transcribe-step success matches `contains(@text,'Transcript')`
   in the UI dump (specs/005 T017); certain wording changes can false-pass/fail the gate.
3. **Unconditional push in the release tail** — on a passing release run, the script merges and
   pushes `main` + the version branch to `origin` with no offline/dirty-remote guard
   (`android/scripts/smoke-test.ps1:399–403`; specs/005 T018). Don't run release commits on a
   machine whose `origin` state you don't trust.
4. **No process-death persistence** (§6) — state is in-memory only.
5. **Duplicated audio constants** across `AudioRecorder.kt` and `SttService.kt` (§3).
6. **Direct service calls from the ViewModel** (§2) — every new stage added before interface
   extraction raises the refactor cost.
7. **`Function_Mapping.md` is a placeholder** — reserved for a future backend; there is no
   backend. Do not "fill it in" against the on-device REST calls.

## 10. Invariants — violating this breaks X

| # | Invariant | Violating it breaks |
| :- | :--- | :--- |
| I1 | Audio between stages is PCM 16-bit / 16 kHz / mono; WAV header exactly 44 bytes, stripped before STT upload | GCP STT decoding (garbled/mis-rated audio → empty or garbage transcripts), `MediaPlayer` playback, and Chunk-4 buffer compatibility |
| I2 | `sampleRateHertz` sent to GCP equals `AudioRecorder.SAMPLE_RATE` (single source: `SttService.kt:51`) | Transcription accuracy silently (GCP resamples/mis-reads; no hard error) |
| I3 | `GCP_STT_API_KEY` lives only in gitignored `local.properties`, injected via `buildConfigField` | Credential secrecy — the repo is on GitHub; a committed key is a live billing/abuse leak |
| I4 | Service failures return `Result.failure` with human-readable messages; UI shows an error card, never crashes | The smoke-test crash gate + Transcribe-without-key step → release auto-merge stops working |
| I5 | UI button/label strings match the smoke test's text-based selectors | The release gate (text selectors can't find elements → every release fails) |
| I6 | All work on `vX.Y.Z` branches; CHANGELOG.md update is THE release signal; never commit to `main` directly; never merge manually around the hook | Release provenance and the auto-merge audit trail (this exact bypass caused the v0.0.5 incident — see voicebridge-failure-archaeology) |
| I7 | Editing/replacing a stage's input clears its downstream derived outputs (transcript edit → translation cleared; new recording → both cleared) | User trust: stale English shown for new Gujarati — the worst possible failure for this app's purpose |
| I8 | New pipeline stages register in the Pipeline Stage Registry (`Project_Structure.md`) with the agreed interface name, and every file add/remove lands in the Project_Structure changelog table | `scripts/verify_structure.py` gate + the agent-navigation premise of `GEMINI.md` Lesson 1 |
| I9 | Vendor calls stay OUT of composables; `MainActivity` renders `UiState` and forwards events only | Testability and the (pending) provider extraction; also rotation behavior, since state must live in the ViewModel |
| I10 | Only Chunk-N scope ships in a Chunk-N version; unshipped work stays `[ ]` in specs tasks | The chunk de-risking model and spec truthfulness (retro-specs 001–005 are as-built records, not aspirations) |
| I11 | `AudioRecorder.stop()` never cancels the writer job before the header back-fill completes | Every recording after the change is an invalid WAV (playback fails, STT gets header-less garbage sizes) |
| I12 | Nothing documents a route around change control; the only sanctioned exception is the exact Bruno acknowledgment string in `PATTERNS.md:10` | The entire governance model (`GEMINI.md` gated commits) |

## Provenance and maintenance

Authored 2026-07-13 by skill-distill (retiring-fellow handover). Facts verified against the
working tree on that date. Re-verify volatile claims before relying on them:

| Claim | One-line re-verification (PowerShell, from repo root) |
| :--- | :--- |
| Chunk status table | `Select-String -Path README.md -Pattern 'Not started'` |
| Provider interfaces still not extracted | `Select-String -Path android/app/src/main/java/com/mananpatel/voicebridge/*.kt -Pattern 'interface STTProvider', 'interface TranslationProvider'` (expect no hits) |
| Services still Kotlin objects called from ViewModel | `Select-String -Path android/app/src/main/java/com/mananpatel/voicebridge/SttService.kt -Pattern 'object SttService'` |
| Audio constants | `Select-String -Path android/app/src/main/java/com/mananpatel/voicebridge/AudioRecorder.kt -Pattern 'SAMPLE_RATE'` |
| Key injection | `Select-String -Path android/app/build.gradle.kts -Pattern 'GCP_STT_API_KEY'` |
| Open spec tasks (gaps) | `Select-String -Path specs\*\tasks.md -Pattern '\[ \]'` |
| Unconditional push still present | `Select-String -Path android/scripts/smoke-test.ps1 -Pattern 'push origin'` |
| Kotlin plugin form (AGP-9 migration volatile) | `Select-String -Path android/app/build.gradle.kts,android/build.gradle.kts -Pattern 'kotlin'` and `git status --short android` |
| Registry table intact | `Select-String -Path Project_Structure.md -Pattern 'STTProvider'` |

If any check disagrees with this file, trust the repo, then update this skill (and only this
skill) accordingly.
