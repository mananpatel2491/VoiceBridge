---
name: voicebridge-chunk3-voice-clone-tts-campaign
description: Executable, decision-gated campaign runbook for VoiceBridge Chunk 3 — voice-cloning TTS (speak the translated English text in the grandparent's own cloned voice; later, Gujarati output in the child's direction). Load this skill when the task is to start, resume, evaluate, spike, design, or ship any part of Chunk 3 TTS — provider selection (ElevenLabs vs GCP Chirp 3 vs IndicF5 vs device-native), clone-quality spikes, the TTSProvider interface, TTS playback integration, or promoting a TTS increment through the release gate. Also load it when someone asks "which TTS should VoiceBridge use", "how do we clone the grandparent's voice", or "what's next for Chunk 3". Do NOT load it for general build/emulator problems (voicebridge-build-and-env), release mechanics unrelated to TTS (voicebridge-release-gate-runbook), STT/Translation API work (voicebridge-gcp-speech-apis-reference), or the recorded-audio WAV pipeline itself (voicebridge-audio-pipeline-reference).
---

# Chunk 3 Campaign: Voice-Clone TTS

You are executing the hardest open feature in VoiceBridge: take the English text
produced by Chunk 2 translation and SPEAK it in the grandparent's own (cloned)
voice, so the 4-year-old hears "Grandma's voice speaking English". The eventual
mirror direction (child's English → Gujarati spoken in the child's voice) is in
scope for planning but NOT for the first shippable increment.

Status as of 2026-07-13: Chunk 3 is NOT STARTED. Nothing in this skill describes
shipped code except the Chunks 0–2 integration points it builds on. Everything
labeled **candidate** or **unproven** stays that way until a Phase 2 spike proves it.

## Jargon (defined once)

| Term | Meaning here |
| :--- | :--- |
| TTS | Text-to-Speech: text in, audio out. |
| Voice cloning | TTS that mimics a specific real person's voice from a short reference recording (also "instant custom voice", "IVC"). |
| Reference audio | The short recording of the grandparent used to build the clone. Treat like a credential (see Fenced-off paths). |
| Provider interface | A Kotlin interface (`TTSProvider`) that hides the vendor behind a swappable abstraction — required by `PATTERNS.md:20`. |
| Audio contract | PCM 16-bit, 16 kHz, mono (`PATTERNS.md:23`); WAV files carry a 44-byte header (`AudioRecorder.kt:29-33`). |
| Chunk 4 | Future real-time two-phone relay. Chunk 3 decisions must not paint it into a corner (streaming, latency). |
| Spec Kit chain | `specify → clarify → plan → tasks → implement` (`GEMINI.md:53-56`); mandatory for a feature this size. |
| Release gate | Version branch `vX.Y.Z` + CHANGELOG update in a commit → post-commit hook runs `smoke-test.ps1 -Build -AutoMerge` (`PATTERNS.md:33-37`). |

## When NOT to use this skill

| You are actually doing… | Use instead |
| :--- | :--- |
| Fixing Gradle/JDK/emulator/AVD problems | voicebridge-build-and-env |
| Running or debugging the smoke test / hook / merge mechanics generally | voicebridge-release-gate-runbook |
| STT or Translation API behavior, quotas, error codes | voicebridge-gcp-speech-apis-reference |
| WAV format, recorder/player internals, header math | voicebridge-audio-pipeline-reference |
| Deciding whether a change needs the Spec Kit chain / CHANGELOG rules | voicebridge-change-control |
| App crash triage, logcat archaeology | voicebridge-debugging-playbook |
| Past incidents (v0.0.5 manual-merge bypass, 88ac97a hook fix) | voicebridge-failure-archaeology |
| Interface/layer questions not TTS-specific | voicebridge-architecture-contract |
| API keys / BuildConfig / local.properties mechanics in general | voicebridge-config-and-flags |
| Writing docs, changelog style, spec formatting | voicebridge-docs-and-writing |
| Adding tests / QA coverage generally | voicebridge-validation-and-qa |
| Smoke-test tooling, screenshots, uiautomator tricks | voicebridge-diagnostics-and-tooling |
| Exploring beyond-Chunk-4 ideas (on-device models, new research) | voicebridge-research-frontier |

---

# Phase 0 — Constitutional constraints (read BEFORE any vendor account is created)

These are non-negotiable. Every one is cited to the constitution of record
(`GEMINI.md`) or the pattern registry (`PATTERNS.md`). GEMINI.md wins over
everything, including this skill.

**Checklist — all boxes must be true before Phase 2 spend or Phase 3 code:**

- [ ] **Cost gate (GEMINI.md:31-34, rule 5).** Every infra-dependent feature
  requires a Terraform update targeting GCP, a projected monthly cost at expected
  call volume, and a `terraform plan` BEFORE any GitHub tagging. Decision rule
  for Chunk 3:
  - Device → vendor REST call only (like `SttService.kt` / `TranslationService.kt`
    today): no new GCP infra → no terraform change, but you STILL write the
    projected-cost paragraph into the spec (`terraform/README.md` cost-awareness
    section demands per-second/per-character projections for voice APIs).
  - Any self-hosted component (e.g., an IndicF5 server on Cloud Run/GCE): full
    rule-5 treatment — terraform module under `terraform/modules/`, cost
    projection, `terraform plan` output attached to the spec. This would also be
    the repo's FIRST backend, which activates the Bruno gate (GEMINI.md:24-29):
    no backend API feature is complete without a Bruno collection.
- [ ] **Free-tier-first bias.** Chunks 1–2 were chosen partly for free tier +
  credential reuse (README.md:9-35). Prefer the option that costs $0/month at
  family-call volume; a paid option needs an explicit justification line in the
  spec ("what the free option cannot do").
- [ ] **Audio contract (PATTERNS.md:23).** All audio exchanged between pipeline
  stages is PCM 16-bit, 16 kHz, mono. TTS output that arrives in another format
  must either be requested in-contract from the vendor (preferred) or converted
  before it touches shared pipeline code; any exception must be documented in
  PATTERNS.md with rationale.
- [ ] **Provider interface REQUIRED (PATTERNS.md:20).** "Never call a vendor SDK
  directly from business logic." Chunk 3 MUST introduce a real `TTSProvider`
  Kotlin interface — the FIRST provider interface actually extracted in this
  codebase (the Pipeline Stage Registry names `STTProvider`/`TranslationProvider`
  at `Project_Structure.md:55-56` but they were never extracted — open tasks
  003/T012 and 004/T012). Do not repeat that debt for TTS: the registry row
  `Project_Structure.md:58` says `TTSProvider | TBD`, and Chunk 3 fills it with
  an interface + a concrete impl, not a bare service object.
- [ ] **Streaming-first (PATTERNS.md:21, GEMINI.md:42-43).** A buffered
  (non-streaming) first implementation is acceptable ONLY if marked as
  batch/buffered in the changelog entry, and the chosen provider must have a
  streaming path available for Chunk 4 (score it in Phase 1).
- [ ] **Latency budget (PATTERNS.md:24).** When the TTS stage lands, add its
  expected P50/P95 row to `Project_Structure.md` (measure in the Phase 2 spike).
- [ ] **Spec Kit chain mandatory (GEMINI.md:53-56).** Chunk 3 is far beyond a
  trivial fix. Run `/speckit-specify` → `/speckit-clarify` → `/speckit-plan` →
  `/speckit-tasks` → `/speckit-implement`; artifacts land in `specs/006-*/`
  (001–005 exist; next number is 006 — re-check with `ls specs/`).
- [ ] **Privacy (PATTERNS.md:12 "audio data leakage").** The reference audio is a
  recording of a family member's voice. Treat it EXACTLY like a credential:
  gitignored, never committed, never pasted into a spec, uploaded only to the
  vendor actually chosen, deleted from vendor dashboards when a spike loses.

**Gate 0 exit criteria:** you can state, in one sentence each, (a) whether the
chosen direction adds GCP infra, (b) the projected monthly cost, (c) how the
provider interface will be shaped. If you cannot → you are not done with Phase 0.

---

# Phase 1 — Provider survey (ranked solution menu)

All vendor facts below were verified by web research on **2026-07-13** and WILL
drift. Re-verify before spending money (re-verification commands in the
Provenance section). Full scoring detail, sources, and re-check URLs:
`references/provider-survey-2026-07-13.md`.

Scoring axes: (1) English cloned output, (2) Gujarati cloned output — this is
the hard axis, verified per provider, (3) latency fit for realtime Chunk 4,
(4) cost vs free tier, (5) credential/vendor synergy with the existing GCP key,
(6) offline capability.

## Ranked menu (as of 2026-07-13)

| Rank | Option | EN clone | GU clone | Chunk-4 latency | Cost | Cred synergy | Offline | Verdict |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| 1 | **ElevenLabs** Instant Voice Clone + `eleven_multilingual_v2` / `eleven_flash_v2_5` | Strong (proven category leader) | Only via `eleven_v3` (70+ langs incl. Gujarati; v3 is expressive-tier, NOT the low-latency model) — **candidate, unproven** | Flash v2.5 ≈75 ms model latency, streaming API — best-in-menu | Free tier 10k credits/mo but **cloning requires Starter ≈$5-6/mo** | None (new vendor, new `ELEVENLABS_API_KEY`) | No | **Primary spike candidate** for the EN direction |
| 2 | **GCP Cloud TTS, Chirp 3 HD voices (NON-cloned)** `gu-IN` + `en-US` | No (stock voices, not cloned) | No (stock `gu-IN` voice exists — identity-lite) | Streaming supported; REST v1 also fine for buffered v1 increment | **1M chars/mo free**, then $30/1M — effectively $0 at family volume | **Same GCP project; API-key auth like SttService** | No | **Fallback / stepping-stone**: ships "spoken English output" without cloning; upgrade path to #3 |
| 3 | **GCP Chirp 3 Instant Custom Voice** (real cloning, ~10 s reference, `gu-IN` IS in its 31-locale list) | Yes | Yes — the only surveyed cloud option with first-party Gujarati cloning | Streaming supported | $60/1M chars, **no free tier** | Same GCP project BUT **allowlist-gated (contact Google sales)** + OAuth bearer, not simple API key + mandatory spoken consent statement | No | **Blocked-by-default candidate**: pursue the allowlist in parallel; do not plan the ship date around it |
| 4 | **AI4Bharat IndicF5** (self-hosted, MIT license, 0.4B params) | Not listed (11 Indian languages only) | **Yes — Gujarati with reference-audio cloning, MIT-licensed** | Self-hosted inference; latency = your hardware; **unproven** | $0 software; hosting = new infra → **full GEMINI.md rule-5 cost gate + terraform + first backend (Bruno gate)** | None; anti-synergy (new infra) | Server-local possible, not on-device | **GU-direction candidate** for the future child→grandparent leg; too heavy for the first EN increment |
| 5 | **Device-native Android `TextToSpeech`** | No cloning | Gujarati availability is engine/device-dependent — check `isLanguageAvailable(Locale("gu","IN"))` at runtime | On-device ≈ instant | $0 | n/a | **Yes — only offline option** | **Error-path fallback only** (speak the text in a generic voice when network/vendor fails) |
| — | Coqui XTTS-v2 class | Yes | **No — Gujarati NOT in its 17 languages** | Needs GPU server | $0 but CPML license is non-commercial and Coqui shut down Jan 2024 | None | Server-local | **REJECTED for Chunk 3** (fails the hard axis) |

## Decision gate 1

Expected decision (2026-07-13 snapshot): **spike #1 (ElevenLabs) and #2 (GCP
Chirp 3 HD non-cloned) side by side.** #1 tests real cloning for the EN
direction; #2 tests the $0 same-key path and doubles as the production fallback.
Record the decision + scores in `specs/006-*/research.md`.

Branches:
- If the family judges non-cloned Chirp 3 HD "good enough for the kid" → ship #2
  first (cheapest, fastest, same key), keep cloning as a follow-up version.
- If ElevenLabs Gujarati-via-v3 matters NOW (child direction) → add a v3 spike
  leg, but treat v3 latency as disqualifying for Chunk 4 realtime until measured.
- If the GCP Instant Custom Voice allowlist request is granted while spiking →
  add it as spike leg 3; it is the only path to first-party GU cloning.
- If budget answer is "strictly $0/month" → #2 + #5 only; cloning waits.

---

# Phase 2 — Spike protocol (prove clone quality + latency BEFORE designing code)

A spike is throwaway; it happens OUTSIDE the app (curl/PowerShell), needs no
version branch, and MUST NOT touch app code. Work in a scratch dir **OUTSIDE
the repo tree**, e.g. `$env:TEMP\vb-spike-tts\` — NOT anywhere under
`C:\Docs\Build\mananUtils\VoiceBridge\`. Two reasons: (1)
`scripts/verify_structure.py` walks the DISK tree regardless of git tracking,
so an in-repo scratch dir turns the structure gate red on the next
version-branch commit; (2) spike files contain family voice audio (a biometric
credential) and must never even be stageable (`*.wav`/`*.pcm` are gitignored
at the repo root, but e.g. spike `.json` responses are not).

## 2.1 Capture the reference sample (uses shipped Chunks 0–2, no new code)

1. Build + install the app and record 30–60 s of the grandparent speaking
   naturally (Gujarati is fine — cloning cares about voice, not language):
   Record → speak → Stop.
2. The recording lands at app-internal storage `files/recording.wav`
   (`MainActivity.kt:26`). Pull it (debug build allows `run-as`):

```powershell
cd C:\Docs\Build\mananUtils\VoiceBridge
New-Item -ItemType Directory -Force $env:TEMP\vb-spike-tts | Out-Null
C:\Android\platform-tools\adb.exe shell "run-as com.mananpatel.voicebridge cat files/recording.wav > /sdcard/recording.wav"
C:\Android\platform-tools\adb.exe pull /sdcard/recording.wav $env:TEMP\vb-spike-tts\grandparent-ref.wav
C:\Android\platform-tools\adb.exe shell rm /sdcard/recording.wav
```

Do NOT use `adb exec-out ... > file` from PowerShell 5.1 — the `>` redirect
re-encodes native binary stdout as text and corrupts the WAV (see
voicebridge-diagnostics-and-tooling section 3); the two-step `/sdcard` route
above is byte-safe. Then verify BEFORE uploading anything to a vendor:

```powershell
python .claude/skills/voicebridge-diagnostics-and-tooling/scripts/inspect_wav.py $env:TEMP\vb-spike-tts\grandparent-ref.wav
```

must report a valid, contract-clean WAV (exit 0) — this catches any corrupted
pull.

**Expected:** a WAV > ~1 MB for 60 s (16 kHz × 2 bytes ≈ 32 KB/s + 44-byte
header). **If 0 bytes instead** → app not installed as debug / wrong app id →
branch to voicebridge-build-and-env. **If it plays as noise** → first verify
the pull was byte-safe (inspect_wav.py above; a `>` redirect of exec-out
corrupts binary in PowerShell 5.1 — voicebridge-diagnostics-and-tooling
section 3); only if a byte-safe pull still fails inspection is it a header
issue → branch to voicebridge-audio-pipeline-reference.

3. Also prepare the test sentence both spikes will speak, e.g. the Chunk 2
   output for a real utterance: run Transcribe + Translate in the app and copy
   the English text. Keep a fixed sentence so legs are comparable.

## 2.2 Spike leg A — ElevenLabs (candidate #1)

Prereqs: create an account, subscribe Starter (cloning is NOT on the free tier
as of 2026-07-13 — re-verify at https://elevenlabs.io/pricing), copy the API key
into an environment variable for the session only (never a file in the repo):

```powershell
$env:XI_KEY = "<paste key>"   # session-only; do NOT write to any file
```

1. Create the instant voice clone from the reference sample:

```powershell
curl.exe -s -X POST "https://api.elevenlabs.io/v1/voices/add" `
  -H "xi-api-key: $env:XI_KEY" `
  -F "name=vb-spike-grandparent" `
  -F "files=@$env:TEMP\vb-spike-tts\grandparent-ref.wav"
```

**Expected:** JSON containing `"voice_id": "..."`. **If 4xx about subscription**
→ cloning not enabled on your tier → upgrade or abandon leg A. **If audio
rejected** → sample too short/noisy → re-record 2.1 with ≥60 s.

2. Synthesize the fixed English sentence with the cloned voice, requesting
   in-contract PCM (verify `output_format=pcm_16000` is allowed on your tier —
   tier-gating of PCM formats is a known ElevenLabs pattern; if rejected, take
   `mp3_44100_128` for the LISTENING test only and note that the integration
   will need the PCM question answered):

```powershell
$voiceId = "<voice_id from step 1>"
$body = '{"text":"<fixed English sentence>","model_id":"eleven_multilingual_v2"}'
Measure-Command {
  curl.exe -s -X POST "https://api.elevenlabs.io/v1/text-to-speech/$voiceId`?output_format=pcm_16000" `
    -H "xi-api-key: $env:XI_KEY" -H "Content-Type: application/json" `
    -d $body -o $env:TEMP\vb-spike-tts\leg-a-cloned.pcm
} | Select-Object TotalMilliseconds
```

**Expected:** non-empty output file; `TotalMilliseconds` recorded as the
buffered-call latency datapoint. Note pcm_16000 is raw headerless PCM — to
listen on Windows, wrap it or re-request as mp3 for the listening copy.

3. (Optional leg A′ — GU direction) repeat step 2 with `"model_id":"eleven_v3"`
   and a Gujarati sentence. **Candidate/unproven:** v3 Gujarati clone quality
   and v3 API latency are exactly what this leg measures.

## 2.3 Spike leg B — GCP Chirp 3 HD (candidate #2, non-cloned, same GCP key)

Prereq: enable "Cloud Text-to-Speech API" in the SAME GCP project as STT/
Translation (console → APIs & Services → Library). The existing
`GCP_STT_API_KEY` then covers it (same pattern as Chunk 2, README.md:124-139).

```powershell
$key = "<value of GCP_STT_API_KEY from android\local.properties>"
$bodyB = '{"input":{"text":"<fixed English sentence>"},"voice":{"languageCode":"en-US","name":"en-US-Chirp3-HD-Aoede"},"audioConfig":{"audioEncoding":"LINEAR16","sampleRateHertz":16000}}'
Measure-Command {
  curl.exe -s -X POST "https://texttospeech.googleapis.com/v1/text:synthesize?key=$key" `
    -H "Content-Type: application/json" -d $bodyB -o $env:TEMP\vb-spike-tts\leg-b-response.json
} | Select-Object TotalMilliseconds
```

**Expected:** JSON with a base64 `audioContent` field; decode to WAV:

```powershell
$b64 = (Get-Content $env:TEMP\vb-spike-tts\leg-b-response.json | ConvertFrom-Json).audioContent
[IO.File]::WriteAllBytes("$env:TEMP\vb-spike-tts\leg-b.wav", [Convert]::FromBase64String($b64))
```

**If 403 "API not enabled"** → enable the API, wait ~1 min, retry. **If the
voice name is rejected** → voice list drifted since 2026-07-13; list live voices:
`curl.exe -s "https://texttospeech.googleapis.com/v1/voices?key=$key&languageCode=en-US"`
and pick a Chirp3-HD entry. Repeat with `languageCode=gu-IN` + a `gu-IN`
Chirp3-HD voice for the identity-lite Gujarati datapoint.

## 2.4 Measurable acceptance (gate 2 exit)

| Check | Method | Pass threshold |
| :--- | :--- | :--- |
| Clone resemblance | Side-by-side blind listen: the Director + one family member hear (ref sample, leg A output, leg B output) and answer "does A sound like grandma?" | ≥ "clearly recognizable as her voice" from BOTH listeners; the 4-year-old recognizing it is the gold standard |
| Intelligibility | Same listeners: "is every word clear?" | No misheard words in the fixed sentence |
| Buffered latency | `Measure-Command` values from 2.2/2.3, 5 runs each, note median + worst | Record as P50/P95 candidates; no hard threshold for Chunk 3 (buffered), but flag anything >3 s as a Chunk 4 risk |
| Cost per utterance | chars in fixed sentence × provider rate | Projected monthly cost at ~30 min of calls/week fits the Phase 0 budget sentence |

**Record all four rows in `specs/006-*/research.md`.** Then delete the
`$env:TEMP\vb-spike-tts\` contents (they hold family voice audio), and delete
the uploaded voice from the loser vendor's dashboard (privacy rule, Phase 0).

**Branches:** Both legs fail resemblance → escalate to Director with the menu
re-ranked (options 3/4 move up; this becomes a research task →
voicebridge-research-frontier). Leg A passes but cost is rejected → ship leg B
as the non-cloned increment and park cloning.

---

# Phase 3 — Integration design gates (before /speckit-implement)

Design decisions the spec/plan MUST settle, each with its default answer:

## 3.1 TTSProvider interface (the first real provider interface in the repo)

Fills the `Project_Structure.md:58` registry row. Default shape (adjust in the
plan, not ad hoc in code):

```kotlin
// android/app/src/main/java/com/mananpatel/voicebridge/TTSProvider.kt
interface TTSProvider {
    /**
     * Synthesize [text] to a WAV file honoring the audio contract
     * (PCM 16-bit, 16 kHz, mono — PATTERNS.md "Audio Format Contract").
     * Returns the written file, or failure with a human-readable message
     * (same Result convention as SttService.kt / TranslationService.kt).
     */
    suspend fun synthesize(text: String, outputFile: File): Result<File>
}
```

- Concrete impls are classes like `ElevenLabsTTS` / `GoogleChirpTTS` implementing
  it — named exactly per the PATTERNS.md:20 examples. Injected into
  `MainViewModel` (constructor default is fine — no DI framework exists and none
  is needed), NEVER instantiated vendor-specifically inside a ViewModel method.
- Streaming: the v1 increment may be buffered, but ONLY if the changelog entry
  says "buffered" (PATTERNS.md:21). Keep the interface extensible (a streaming
  `synthesizeStream` overload is a Chunk 4 addition, don't speculate it now).

## 3.2 Where playback lands

`AudioPlayer.kt` already plays any WAV file via MediaPlayer (`AudioPlayer.kt:15`).
Default: `TTSProvider.synthesize` writes `File(filesDir, "tts-output.wav")` and
the existing `AudioPlayer` plays it — no new playback code. This is exactly why
gate 3.3 forces WAV-with-header output. **If the chosen vendor cannot return
16 kHz WAV/PCM** → convert in the impl class (header-wrap raw PCM using the same
44-byte layout as `AudioRecorder.buildWavHeader`, `AudioRecorder.kt:97-120`) —
do NOT relax the contract, and do NOT teach AudioPlayer vendor formats.

## 3.3 Audio contract compliance

- ElevenLabs: request `output_format=pcm_16000` (raw PCM → wrap with 44-byte
  header in `ElevenLabsTTS`). Tier availability of PCM formats: verify in the
  spike (2.2 step 2).
- GCP: request `audioEncoding=LINEAR16, sampleRateHertz=16000` — the v1 REST
  response's decoded `audioContent` is WAV-headered LINEAR16 (verify the first
  4 bytes are `RIFF` in the spike output; if headerless, wrap as above).

## 3.4 UI + error-card contract

Follow the Chunk 2 template exactly (it is the KEEP-IN-SYNC contract with the
smoke test):
- New `UiState` fields `isSpeaking: Boolean`, plus a status message — extend the
  data class at `MainViewModel.kt:13-22`.
- Failures surface via the existing `errorMessage` field → the red error Card at
  `MainActivity.kt:93-101`. A missing key produces the same style of message as
  `MainViewModel.kt:76` ("ELEVENLABS_API_KEY is not set..." etc.) so the smoke
  test can assert on it WITHOUT a live credential.
- New button label: `"Speak (English)"` (exact string is a design choice — but
  once chosen it is FROZEN into the smoke-test selectors; see 3.6).
- Enabled-state rule: disabled until `translatedText` is non-empty.

## 3.5 Credential wiring

Mirror the existing key exactly (`android/app/build.gradle.kts:27-31`):
- New vendor key → new `buildConfigField` sourced from `local.properties`, blank
  default, clear error when blank. Update `android/local.properties.template`
  with a commented Chunk 3 section.
- GCP-only path → reuse `GCP_STT_API_KEY` (enable the TTS API in the project);
  no new key. Note the key name is historical — it already covers Translation
  (`TranslationService.kt:26-29`); do not rename it in this feature (scope).

## 3.6 Smoke-test extension (a TTS step JOINS the KEEP-IN-SYNC set)

`android/scripts/smoke-test.ps1` says at :26 and PATTERNS.md:42: selectors must
stay in sync with `MainActivity.kt` labels. The Chunk 3 version MUST add, after
the translate step (smoke-test.ps1:306-344 is the template to copy):
1. Assert the Speak button exists and is disabled initially (pattern:
   `Assert-Enabled`, smoke-test.ps1:131-140).
2. After the translate step produces text (or the typed-"hello" fallback path),
   tap Speak; assert EITHER a speaking/spoken status appears OR an error card
   (missing key — the CI-expected outcome), exactly like the transcribe step's
   either/or at smoke-test.ps1:284-303. Either outcome proves the flow fires
   without crashing; the crash scan at :346-350 stays the hard gate.
3. Screenshot the result (`Save-Shot "speak-result"`).
The script is ASCII-only (smoke-test.ps1:28) — keep new strings ASCII.

**Gate 3 exit:** `specs/006-*/plan.md` records answers to 3.1–3.6.

---

# Phase 4 — Validation and promotion through change control

Never route around this. The v0.0.5 incident (manual merge WITHOUT a CHANGELOG
entry, bypassing the auto-merge signal; fixed retroactively in v0.0.7) is the
cautionary tale — see voicebridge-failure-archaeology.

1. **Spec Kit chain first** (`GEMINI.md:53-56`): `/speckit-specify` the Chunk 3
   increment → `/speckit-clarify` → `/speckit-plan` → `/speckit-tasks` →
   `/speckit-implement`. Artifacts in `specs/006-<slug>/`. The Phase 1 menu and
   Phase 2 measurements go into `research.md`; Phase 0 cost sentence into
   `plan.md`.
2. **Cost gate before any tagging** (`GEMINI.md:33`): if infra was added, run
   `terraform plan` and attach projected cost; if device-direct REST only,
   the projected-cost paragraph in the spec satisfies the review. Deployment/
   tagging is prohibited until this is done.
3. **Version branch**: latest release is 0.0.7 (CHANGELOG.md, 2026-07-13 —
   re-check `head CHANGELOG.md`). Work on `git checkout -b v0.0.8` (or current
   next). Never commit to main (`PATTERNS.md:33`).
4. **Docs in the SAME commit(s)**:
   - `Project_Structure.md`: new file rows (TTSProvider.kt, impl class),
     changelog-table row (GEMINI.md:12 — mandatory, enforced by
     `scripts/verify_structure.py` which runs inside the smoke test,
     smoke-test.ps1:163-172), Pipeline Stage Registry TTS row updated from TBD,
     and the latency-budget P50/P95 row from the spike (PATTERNS.md:24).
   - `PATTERNS.md`: mark the increment buffered-not-streaming if true; document
     any audio-format exception.
   - `README.md`: add "Chunk 3 acceptance test" section following the exact
     format of Chunks 1–2 (README.md:141-154): numbered manual steps ending in
     "a clear error card appears" for the missing-key case; flip the Chunk
     Status table row (README.md:74) to Built.
5. **Intermediate commits** (no CHANGELOG touch) on v0.0.8 run the smoke test
   only (PATTERNS.md:35) — use freely while implementing.
6. **Release commit**: update `CHANGELOG.md` ([0.0.8] section; note "buffered"
   if applicable; note $/month) + bump `versionCode`/`versionName` in
   `android/app/build.gradle.kts:22-23`, commit `chore: v0.0.8`. The post-commit
   hook then runs `smoke-test.ps1 -Build -AutoMerge`; on pass it merges to main
   and pushes both branches. **Expected:** green summary + "Merged and pushed".
   **If the smoke test fails** → fix on the branch; do NOT merge manually (that
   is the v0.0.5 incident) → voicebridge-release-gate-runbook.
7. **Acceptance with the real key(s)**: run the README Chunk 3 acceptance test
   on a device with credentials configured; the child recognizing the voice is
   the product-level pass.

---

# Fenced-off wrong paths (do not do these, ever)

| Wrong path | Why it is fenced | Do instead |
| :--- | :--- | :--- |
| Hard-coding a vendor SDK/HTTP call into `MainViewModel` or `MainActivity` | Violates PATTERNS.md:20 (provider interface); repeats the STTProvider/TranslationProvider debt | `TTSProvider` interface + injected impl (Phase 3.1) |
| Emitting/accepting audio off-contract (e.g., 44.1 kHz MP3 into shared pipeline code) | Violates PATTERNS.md:23; breaks AudioPlayer assumptions and Chunk 4 PCM plans | Request 16 kHz PCM/LINEAR16; convert inside the impl class (3.2/3.3) |
| Committing ANY voice sample of a family member (reference audio, spike outputs, smoke screenshots of nothing — audio files specifically) | Privacy; PATTERNS.md:12 names audio data leakage a security risk. A voice sample is a biometric credential | Keep samples in a scratch dir OUTSIDE the repo tree (Phase 2); delete vendor-side clones for losing spikes |
| Shipping/tagging without the cost projection (+ `terraform plan` if infra) | Direct violation of GEMINI.md:31-34 rule 5 | Phase 4 step 2 |
| Manually merging to main / skipping the CHANGELOG signal | The v0.0.5 incident; PATTERNS.md:33-35 | Release commit + hook (Phase 4 step 6) |
| Putting the ElevenLabs (or any) key anywhere but `local.properties` → `buildConfigField` | Credential hygiene; the smoke test pre-flight fails if local.properties is tracked (smoke-test.ps1:156-161) | Phase 3.5 |
| Adding the TTS button without extending the smoke test selectors | Breaks the KEEP-IN-SYNC contract (smoke-test.ps1:26, PATTERNS.md:42); the release gate would pass while blind to the new feature | Phase 3.6 |
| Skipping the Spec Kit chain because "it's just one API call" | GEMINI.md:54 — any feature beyond a trivial fix; Chunk 3 is a named roadmap chunk | Phase 4 step 1 |

The ONLY sanctioned change-control exception in this repo is the exact Bruno
acknowledgment string in PATTERNS.md:10 — and it applies to Bruno validation
only, which is dormant until a backend exists.

---

# Open questions (all candidate/unproven as of 2026-07-13)

- ElevenLabs `eleven_v3` Gujarati clone quality and latency — measured by spike leg A′, not by marketing pages.
- ElevenLabs `pcm_16000` output availability on the Starter tier — verify in 2.2.
- GCP Chirp 3 Instant Custom Voice allowlist: will Google grant a personal project? Request early; unblocks first-party GU cloning.
- IndicF5 real-world Gujarati clone quality + CPU-only latency — untested here; would be the repo's first backend.
- Whether the 4-year-old actually responds better to the cloned voice than to a stock voice — the whole bet of Chunk 3; leg B vs leg A listening data is the first evidence.
- Device-native Gujarati TTS availability on the actual family phones — runtime check, per device.

---

# Provenance and maintenance

Authored 2026-07-13 by skill-distill (retiring-fellow distillation). Repo facts
verified against the working tree on 2026-07-13; vendor facts verified by web
research on 2026-07-13 and rot fastest.

Re-verification one-liners:
- Constitution/pattern anchors still hold: `Select-String -Path GEMINI.md -Pattern "terraform plan"` and `Select-String -Path PATTERNS.md -Pattern "TTSProvider|Provider Interface|16 kHz"`
- Registry TTS row still TBD (Chunk 3 still unstarted): `Select-String -Path Project_Structure.md -Pattern "TTSProvider"`
- Next spec number: `ls specs/`
- Latest released version: `Get-Content CHANGELOG.md -TotalCount 15`
- Recording file path unchanged: `Select-String -Path android\app\src\main\java\com\mananpatel\voicebridge\MainActivity.kt -Pattern "recording.wav"`
- ElevenLabs pricing/cloning tier + model languages: https://elevenlabs.io/pricing and https://elevenlabs.io/docs/overview/models
- GCP Chirp 3 HD voices + Instant Custom Voice allowlist status: https://docs.cloud.google.com/text-to-speech/docs/chirp3-hd and https://docs.cloud.google.com/text-to-speech/docs/chirp3-instant-custom-voice ; live gu-IN voice list: `curl.exe -s "https://texttospeech.googleapis.com/v1/voices?key=<KEY>&languageCode=gu-IN"`
- Cloud TTS free tier: https://cloud.google.com/text-to-speech/pricing
- IndicF5 license/languages: https://huggingface.co/ai4bharat/IndicF5
- Build config note (2026-07-13): the AGP built-in-Kotlin migration is committed as of v0.0.8 (no standalone `org.jetbrains.kotlin.android` plugin — see voicebridge-failure-archaeology INC-6).
