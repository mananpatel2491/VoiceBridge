---
name: voicebridge-research-frontier
description: The four open research problems where VoiceBridge pushes past well-trodden ground — Gujarati voice-clone TTS for a low-resource language, the Chunk 4 real-time two-phone acoustic relay (echo/feedback + latency budget), code-switched and child/elderly-speech STT measurement, and the on-device vs cloud split under free-tier cost gates — plus the evidence bar any claimed progress must clear. Load when someone asks "what are the hard open problems", "what should we research next", "is X feasible for VoiceBridge", "how do we prove this spike worked", "what counts as a result", or before ANY exploratory work (spike, model eval, latency measurement, feasibility study). Do NOT load it for executing the Chunk 3 TTS campaign (voicebridge-chunk3-voice-clone-tts-campaign), how the shipped pipeline works (voicebridge-audio-pipeline-reference, voicebridge-gcp-speech-apis-reference), shipping finished work (voicebridge-change-control), or build/runtime debugging (voicebridge-build-and-env, voicebridge-debugging-playbook).
---

# VoiceBridge Research Frontier

VoiceBridge's shipped surface (Chunks 0–2: record → Gujarati STT → gu→en
translation) is well-trodden engineering. What remains is not. This skill names
the four problems where the project leaves the paved road, what the repo already
gives you as a head start on each, the first three concrete moves, and — most
importantly — the evidence bar you must clear before claiming progress.

**STATUS DISCLAIMER (2026-07-13): every idea, provider, model, and number in
this skill is OPEN or CANDIDATE. Nothing here is shipped. Chunks 3 and 4 are
NOT STARTED (`README.md:69-75`). If you find yourself citing this skill as
proof that something works, stop — that is exactly the failure mode it exists
to prevent.**

## Jargon (defined once)

| Term | Meaning here |
| :--- | :--- |
| Chunk | A staged VoiceBridge feature increment. 0=record/play, 1=STT, 2=translation (shipped); 3=voice-clone TTS, 4=real-time two-phone relay (not started). |
| STT / TTS | Speech-to-Text / Text-to-Speech. |
| Voice cloning | TTS that mimics a specific real person's voice from a short reference recording. |
| Code-switching | Mixing two languages inside one utterance (the 4-year-old dropping English words into Gujarati sentences). |
| WER | Word Error Rate — the standard STT accuracy metric (lower is better). Relative WER increase = (new−old)/old. |
| VAD | Voice Activity Detection — deciding "is someone speaking right now" so silence is never sent to a paid API (`PATTERNS.md:22`). |
| AEC | Acoustic Echo Cancellation — removing a device's own playback from what its mic re-captures. |
| RTF | Real-Time Factor — processing time ÷ audio duration. RTF < 1 means faster than real time (required for streaming). |
| Spike | A small, throwaway experiment built only to answer one question with a number. Never merged as product code. |
| Free-tier cost gate | GEMINI.md rule: project costs before any infra tagging (`GEMINI.md:31-34`). Current budget target: $0/month inside GCP free tiers (STT 60 min/mo `README.md:35`; Translation 500K chars/mo `README.md:20`). |
| Family test bench | The actual users: a Gujarati-speaking elderly couple and an English-speaking 4-year-old. The project's unique, irreplaceable evaluation asset. |

---

## The evidence bar (research methodology — read this BEFORE any experiment)

VoiceBridge is a one-developer personal project with a real family depending on
the result. There is no peer review. These four rules substitute for it.

### 1. The hypothesis predicts numbers BEFORE the experiment

Write down the predicted value — WER, latency in ms, similarity score, cost in
dollars — before you run anything. A hypothesis that cannot be numerically
wrong is not a hypothesis. Concretely: open the spike note (see lifecycle
below), write "I predict gu-IN WER on the child's code-switched speech will be
> 60%", THEN run the measurement. If you catch yourself writing the prediction
after seeing the result, discard the run and re-predict on fresh data.

### 2. One mechanism must explain ALL observations — including the negatives

A claim like "streaming STT cut latency" must come with a mechanism ("removed
the N-second full-utterance buffering wait") that also explains every case
where latency did NOT improve. If two observations need two different stories,
you do not understand the system yet and may not claim a result. This repo has
lived this lesson: the v0.0.3 post-commit hook "passed" its smoke test while
silently never building the new APK — the single mechanism (missing `-Build`
flag, fixed in commit 88ac97a) explained both the false green and the stale
behavior. See voicebridge-failure-archaeology for the full story.

### 3. Adversarial self-refutation before claiming

Before writing "it works", actively try to prove it doesn't. Minimum checklist
for any VoiceBridge audio/speech experiment:

- [ ] **Silent empty ≠ success**: `SttService.kt:78-81` returns `""` (not an
  error) when GCP finds no speech. An experiment that "produced no errors" may
  have transcribed nothing. Always inspect the actual transcript text.
- [ ] **Emulator mic ≠ device mic**: the AVD's virtual mic and a physical
  phone's mic have different noise/gain profiles. A result measured only on the
  emulator is a candidate, not a validated result.
- [ ] **Wrong audio in**: confirm the WAV you scored is the WAV you think it is
  (checksum or listen to it). The 44-byte header strip (`SttService.kt:44-45`)
  means a malformed file can still upload "successfully" as garbage PCM.
- [ ] **Free-tier throttling as confound**: quota exhaustion mid-experiment
  degrades results in ways that look like model failure. Check quota state
  before and after.
- [ ] **Test-bench bias**: results from one grandparent's voice on one phone do
  not generalize even to the other grandparent. State the n.

### 4. Idea lifecycle: candidate → spiked → validated → shipped

| Stage | Meaning | Where the artifact lands |
| :--- | :--- | :--- |
| **candidate** | Named idea, no evidence yet. | This skill; an open `[ ]` task in `specs/NNN-*/tasks.md` (the existing open tasks listed per-problem below are all candidates). |
| **spiked** | One throwaway experiment ran; a number exists. | A spike note in the feature's `specs/NNN-*/research.md` (created by the Spec Kit chain, `GEMINI.md:53-56`) recording prediction, setup, measured number, refutation checklist outcome. Spike code itself is throwaway — never merged. |
| **validated** | Repeated on the real device/family bench; mechanism explains all runs; refutation survived. | An entry in `PATTERNS.md` — which by constitution "must reflect the actual codebase, never aspirational designs" (`GEMINI.md:17`), so nothing enters PATTERNS.md before this stage. |
| **shipped** | Implemented via the full Spec Kit chain, passed the release gate. | `CHANGELOG.md` entry — including a `### Decisions` subsection recording what was chosen and what was REJECTED and why (see `CHANGELOG.md:68-72` and `:95-99` for the established format). |

Promotion between stages goes through change control like everything else:
Spec Kit chain for any non-trivial feature, version branch, CHANGELOG-triggered
release gate. Research is not an exemption from `GEMINI.md`. See
voicebridge-change-control before promoting anything.

---

## Problem 1 — Gujarati voice-clone TTS (Chunk 3): low-resource-language cloning

**Goal**: the 4-year-old hears "Grandma's voice speaking English" — a clone of
the grandparent's voice, built from a short Gujarati reference recording,
speaking the English translation. Status: OPEN, not started.

**Why off-the-shelf fails**: commercial instant-voice-clone products are
trained overwhelmingly on high-resource languages. Two compounding hard parts:
(a) Gujarati is low-resource — clone quality from Gujarati reference audio is
undertested everywhere; (b) this is *cross-lingual* cloning (Gujarati reference
→ English output), which stresses models harder than same-language cloning.
State of the art as of 2026-07-13 (web-searched, not benchmarked in this repo):
AI4Bharat's [IndicF5](https://arxiv.org/pdf/2604.25441) is an open-source
Indic-native TTS base; [A2TTS (2025)](https://arxiv.org/pdf/2507.15272) does
diffusion-based speaker adaptation for Indic languages including Gujarati; and
["Phir Hera Fairy" (2025)](https://arxiv.org/html/2505.20693v1) measured how
English F5-TTS adapts to 11 Indian languages including Gujarati, covering
voice-cloning and code-mixing. All are candidates only — none has been run
against this project's voices.

**Repo asset**: a clean, shipped 16 kHz / 16-bit / mono PCM recording pipeline
(`AudioRecorder.kt:29-33`) that can capture reference audio of the actual
grandparents today, plus the family test bench itself — a real bilingual family
is a rarer evaluation asset than any GPU. Caution: some cloning models expect
higher-sample-rate reference audio; verify each candidate's reference-audio
requirements before recording (16 kHz may be a floor, not a fit).

**First three steps**:
1. Write the evaluation protocol BEFORE touching any model: blinded family
   listening test design, similarity scale, intelligibility scale, and the
   predicted scores per candidate model (evidence-bar rule 1).
2. Capture a reference corpus with the existing app: 3–5 minutes of each
   grandparent's natural speech, catalogued with recording conditions. Treat
   these files like credentials (a voice clone of a real person is sensitive
   data — never commit, never upload beyond the chosen provider).
3. Run a zero-shot clone spike on 2–3 candidates (one commercial, one open
   Indic-native) producing the SAME English sentences, and run the blinded
   family test. Record everything in the Chunk 3 spike note.

Execution detail beyond this framing — provider matrices, decision gates,
integration — lives in voicebridge-chunk3-voice-clone-tts-campaign. This
section defines the research question and the proof standard; that skill runs
the campaign.

**You have a result when**: in a blinded A/B test, ≥3 adult family members rate
the clone's speaker similarity at or above your pre-registered threshold AND the
4-year-old, unprompted, identifies the voice as the grandparent — or when a
candidate demonstrably fails that same test (a clean negative on IndicF5 or
ElevenLabs for Gujarati elderly voices is a publishable-grade result for this
project; record it in `research.md` with the mechanism).

**Existing open candidates in specs**: `specs/004-gujarati-english-translation/tasks.md`
T013 (feed `translatedText` into voice-clone TTS).

---

## Problem 2 — Real-time two-phone acoustic relay over a WhatsApp call (Chunk 4)

**Goal**: during a live WhatsApp video call, a second phone in the room hears
the Gujarati speech, and plays translated English audio back into the room (and
eventually the reverse direction), fast enough to keep a 4-year-old engaged.
Status: OPEN, not started.

**Why off-the-shelf fails**: WhatsApp exposes no API to tap or inject call
audio, and Android restricts programmatic capture of another app's voice-call
audio — so the relay must be *acoustic*: a mic listening to the room and a
speaker playing into it (verify the current Android capture-policy state before
designing around it; policies shift between API levels). That creates the hard
problem: **echo/feedback between two phones sharing one acoustic space**.
Built-in AEC cancels a device's *own known* playback signal; it has no model of
a second, independent device's speaker. Naive implementation = the relay
transcribes its own TTS output in a loop. On top of that sits the **latency
budget**: capture → STT → translate → TTS → playback, each hop today a blocking
cloud REST call. Published live speech-translation systems land at roughly
1.2–3.0 s glass-to-glass as of 2026-07-13
([Fora Soft vendor benchmarks, 2026](https://www.forasoft.com/blog/article/real-time-speech-translation-vendor-benchmarks);
[Deepgram architecture guide](https://deepgram.com/learn/real-time-speech-to-speech-translation)),
with pre-processing (noise suppression / AEC) alone costing 50–150 ms
([Palabra, 2026](https://blog.palabra.ai/al-speech-translation/how-real-time-language-translators-reduce-latency-the-technical-reality/)).
Same-room two-device echo is poorly represented in any published benchmark —
this corner is genuinely unmapped.

**Repo asset**: the PCM path was format-stable by design for exactly this reuse
— "Same PCM buffer format used in Chunk 4's real-time pipeline, so no format
migration later" (`README.md:41`). The capture loop (`AudioRecorder.kt:63-77`)
already reads fixed-size byte buffers in a coroutine; converting file-sink to
live frame-consumer is a seam change, not a rewrite. The needed sub-problems
are already filed as open candidates: streaming capture
(`specs/002-voice-capture-playback/tasks.md` T014), streaming STT
(`specs/003-gujarati-stt/tasks.md` T013), VAD gating (003 T014, 002 T013),
reverse en→gu direction (004 T014), and latency-budget rows (002 T016, 003
T015, 004 T015 — `PATTERNS.md:24` requires P50/P95 per hop, none recorded yet).

**First three steps**:
1. **Measure the baseline before building anything**: instrument the existing
   batch pipeline with per-hop timestamps (capture stop → STT response →
   translation response) and produce the first real latency table over ≥20
   utterances. Predict the numbers first. This also discharges the open
   latency-budget tasks.
2. **Bench the feedback loop in isolation**: two phones, one room; phone B
   plays a fixed English TTS clip while phone A records. Measure whether phone
   A's recording re-transcribes the clip. Then test the cheapest mitigation —
   half-duplex turn-taking (mute capture while playing) — before any signal
   processing. Prediction first: "with half-duplex gating, 0 of 10 played clips
   appear in the transcript."
3. **Spike streaming STT**: GCP streaming recognition is gRPC/WebSocket, not
   the REST endpoint the app uses (`SttService.kt:28`). Its auth model
   (API-key vs OAuth token) is an UNVERIFIED unknown as of 2026-07-13 —
   resolving it is the spike's first deliverable, since the whole app currently
   authenticates with a single API key (see voicebridge-config-and-flags).

**You have a result when**: a spoken Gujarati utterance produces audible
English audio out in ≤ your pre-registered P50 budget (pick the number from the
step-1 baseline before optimizing), measured over ≥20 utterances on physical
hardware, with zero feedback-runaway events — where runaway is defined
falsifiably as: any fragment of the pipeline's own TTS output appearing in a
subsequent transcript.

---

## Problem 3 — Code-switched / child-speech / elderly-speech STT (measurement-first)

**Goal**: know — with numbers — how badly `gu-IN` STT degrades on this family's
three off-distribution speaker classes: (a) a 4-year-old mixing English words
into Gujarati contexts, (b) the same child's speech acoustics generally, (c)
elderly Gujarati speech. Status: OPEN. This is explicitly a MEASUREMENT problem
before it is a modeling problem.

**Why off-the-shelf fails**: the shipped config assumes monolingual adult
Gujarati (`SttService.kt:49-53`, single `languageCode gu-IN`). As of 2026-07-13
the literature reports 30–50% *relative* WER increase on code-switched speech
vs monolingual input
([survey, 2025](https://arxiv.org/pdf/2507.07741)), and child speech is a
known separate degrader — the first Hinglish adult+child code-switched corpus
([HiACC](https://pmc.ncbi.nlm.nih.gov/articles/PMC12329218/)) only appeared in
2025, and **no public Gujarati-English child-speech benchmark exists at all**.
There is no leaderboard to consult: if VoiceBridge wants the number, VoiceBridge
must produce it. That absence is the research opportunity.

**Repo asset**: the shipped app is already a labeling tool. It records a WAV,
transcribes it, and presents the transcript in an *editable* field
(`README.md:143-145` — Chunk 1 acceptance flow; hand-correcting the field
produces a gold transcript for the exact audio just captured). And the family
IS the target distribution — no public corpus can substitute for these three
specific speaker classes.

**First three steps**:
1. Build the family eval set: through the existing app, record ≥50 utterances
   spread across the three speaker classes and across code-switch density
   (pure Gujarati / 1–2 English words / heavy mixing). Hand-correct each
   transcript. Store audio + gold text pairs, versioned, OUTSIDE git (family
   voice data — same sensitivity rule as Problem 1 reference audio).
2. Score the baseline: current `gu-IN` config WER per speaker class and per
   code-switch bucket. Write predictions first (rule 1).
3. A/B candidate configs against the SAME frozen set: GCP
   `alternativeLanguageCodes` / latest GCP model variants, and one non-GCP
   engine (e.g., a Whisper variant) — each behind the provider seam, since the
   `STTProvider` interface named in the Pipeline Stage Registry
   (`Project_Structure.md:52-58`) is itself still an open task
   (`specs/003-gujarati-stt/tasks.md` T012).

**You have a result when**: a versioned eval set (≥50 utterances, 3 speaker
classes, gold transcripts) exists AND per-class WER numbers exist for ≥2
engines. Note carefully: "every engine is bad at the child's code-switched
speech" IS a result — it is the number that justifies (or kills) any future
fine-tuning investment. Absence of improvement is reportable; absence of
measurement is not.

---

## Problem 4 — On-device vs cloud pipeline split under free-tier cost gates

**Goal**: decide, per pipeline stage, whether it runs on the phone or in the
cloud — under the constitution's cost gate (`GEMINI.md:31-34`: projected costs
reviewed before any tagging) and the current $0/month free-tier posture.
Status: OPEN.

**Why off-the-shelf fails**: the free tiers that comfortably cover today's
tap-to-transcribe usage (STT 60 min/mo `README.md:35`, Translation 500K
chars/mo `README.md:20`) are not sized for Chunk 4: a single 30-minute call per
week is ~2 h/mo of continuous audio — 2× the STT free tier from one call
stream, before the reverse direction. Meanwhile on-device inference
(whisper.cpp and TFLite Whisper ports run on Android as of 2026-07-13 —
[whisper_android](https://github.com/vilassn/whisper_android),
[whisper.cpp](https://landscape.jimmysong.io/projects/whisper-cpp/)) removes
the marginal cost but with three unknowns nobody publishes for this exact case:
quantized-small-model *Gujarati* accuracy, RTF on the family's actual phones,
and thermal/battery behavior while a WhatsApp *video call* is simultaneously
running on the device. The general edge-vs-cloud tradeoff is well-trodden; this
project's corner (low-resource language × mid-range phone × concurrent video
call × hard $0 budget) is not.

**Repo asset**: the architecture already anticipates the swap — the Provider
Interface pattern is constitutional (`PATTERNS.md:20`: never call a vendor SDK
from business logic) and the Pipeline Stage Registry
(`Project_Structure.md:50-58`) names `STTProvider`/`TranslationProvider`/
`TTSProvider` slots. Honest caveat: those interfaces are NOT yet extracted in
code (open tasks 003 T012, 004 T012) — extracting them is the enabling move,
not a formality. The cost-gate ritual itself (`GEMINI.md:33`) is the other
asset: the discipline of writing the cost table before building is already law
here.

**First three steps**:
1. Write the cost model FIRST, no code: minutes of speech per typical call ×
   expected calls/month × both directions, against each API's current free
   tier and paid rate (re-verify tier numbers on GCP's pricing pages — they
   drift). Output: a table showing exactly when Chunk 4 usage breaches $0.
2. Spike on-device STT: run a quantized Whisper variant on a physical device
   against the Problem 3 family eval set. Measure the triple (WER, RTF,
   device temperature/battery over a 10-minute run). Predictions first.
3. Draft the split as a decision table — stage × placement × measured
   WER/latency/cost — with the near-certain easy win stated as a candidate:
   VAD always on-device (it exists to avoid paying for silence,
   `PATTERNS.md:22`; putting it in the cloud is self-defeating).

**You have a result when**: the decision table exists with a *measured* (not
estimated) row for at least STT in both placements, and the chosen split's
projected monthly cost is either $0 within verified free tiers or explicitly
approved by the Director — and the losing placement's numbers are recorded in
`research.md` alongside the winner's (rule 2: the mechanism must explain why
the loser lost).

---

## Cross-cutting dependencies between the four problems

- Problem 3's eval set is an INPUT to Problems 2 and 4 (you cannot judge
  streaming or on-device STT without it). If sequencing is undecided, build
  the eval set first — it is cheap and unblocks everything.
- Problem 1 (TTS) and Problem 2 (relay) intersect at latency: a cloned voice
  that takes 8 s to synthesize is fine for Chunk 3's tap-to-speak but dead on
  arrival for Chunk 4. Record TTS synthesis latency in every Problem 1 spike
  even though Chunk 3 itself doesn't need it yet.
- Every problem's implementation work (as opposed to spikes) goes through the
  Spec Kit chain and the release gate — research does not bypass change
  control, and the only sanctioned validation exception in this repo is the
  exact Bruno acknowledgment string in `PATTERNS.md:10`.

## When NOT to use this skill

| You actually want... | Load instead |
| :--- | :--- |
| To execute Chunk 3 TTS work step-by-step (provider selection, spikes, integration, shipping) | voicebridge-chunk3-voice-clone-tts-campaign |
| How the shipped WAV/PCM pipeline works today | voicebridge-audio-pipeline-reference |
| Exact GCP STT/Translation request/response details | voicebridge-gcp-speech-apis-reference |
| Branching, CHANGELOG signal, merge rules for finished work | voicebridge-change-control |
| Running/interpreting the smoke test and release automation | voicebridge-release-gate-runbook |
| The smoke test's QA scope and gaps | voicebridge-validation-and-qa |
| Build environment, JDK/SDK/emulator problems | voicebridge-build-and-env |
| Diagnosing a live failure in existing code | voicebridge-debugging-playbook / voicebridge-diagnostics-and-tooling |
| Past incidents and their mechanisms (e.g., the 88ac97a hook fix, the v0.0.5 bypassed merge signal) | voicebridge-failure-archaeology |
| API keys, BuildConfig injection, local.properties | voicebridge-config-and-flags |
| Architecture map and doc-of-record precedence | voicebridge-architecture-contract |
| Writing/updating the governed docs themselves | voicebridge-docs-and-writing |

## Provenance and maintenance

Authored 2026-07-13 by skill-distill (retiring-fellow distillation run). All
web-sourced state-of-the-art claims were searched 2026-07-13 and will drift;
all repo claims were verified against the working tree on that date.

Re-verification one-liners (PowerShell, from repo root
`C:\Docs\Build\mananUtils\VoiceBridge`):

- Chunk status still 3/4 not started: `Select-String -Path README.md -Pattern "Not started"`
- Open candidate tasks still open: `Select-String -Path specs\*\tasks.md -Pattern "\[ \]"`
- Audio contract unchanged (16 kHz/16-bit/mono/44-byte header): `Select-String -Path android\app\src\main\java\com\mananpatel\voicebridge\AudioRecorder.kt -Pattern "SAMPLE_RATE|WAV_HEADER_SIZE"`
- Empty-transcript-is-not-an-error behavior unchanged: `Select-String -Path android\app\src\main\java\com\mananpatel\voicebridge\SttService.kt -Pattern "no speech detected" -Context 2`
- Provider interfaces still unextracted: `Get-ChildItem android\app\src\main\java\com\mananpatel\voicebridge` (still exactly 6 .kt files ⇒ no `*Provider.kt` yet)
- Pipeline Stage Registry rows: `Select-String -Path Project_Structure.md -Pattern "Provider"`
- Free-tier numbers (README's claim; re-check GCP pricing pages independently): `Select-String -Path README.md -Pattern "free tier" -CaseSensitive:$false`
- CHANGELOG `### Decisions` convention still in use: `Select-String -Path CHANGELOG.md -Pattern "### Decisions"`
- State-of-the-art drift: re-run web searches for "Gujarati voice cloning TTS low-resource", "code-switched child speech ASR corpus", "real-time speech translation latency benchmarks", "whisper.cpp Android" and update the dated citations above.
