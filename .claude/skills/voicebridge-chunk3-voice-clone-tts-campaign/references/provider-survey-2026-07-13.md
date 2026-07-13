# Chunk 3 TTS provider survey — detail sheet (snapshot 2026-07-13)

Companion to `../SKILL.md` Phase 1. EVERY fact on this page was gathered by web
research on **2026-07-13**. Vendor pricing, model language lists, and access
gates drift within months — re-verify from the linked sources before acting on
any row. Where a fact could not be first-party verified, it is marked
**(secondary source — verify)**.

Scoring scale: 0 = fails the axis, 1 = partial/conditional, 2 = strong.

## 1. ElevenLabs (Instant Voice Cloning + model family)

| Axis | Score | Evidence (2026-07-13) |
| :--- | :--- | :--- |
| EN cloned output | 2 | Category leader for instant cloning; clone made from one short sample speaks all languages of the chosen model. |
| GU cloned output | 1 | `eleven_multilingual_v2` (29 langs) and `eleven_flash_v2_5` (32 langs) do NOT list Gujarati. `eleven_v3` (70+ langs) DOES list Gujarati; ElevenLabs demoed cloning in 12 Indian languages incl. Gujarati (IIT Delhi blog post). v3 is the expressive model, not the realtime one — GU cloning is therefore possible but on the slow model. **Unproven for this family's voices.** |
| Chunk-4 latency fit | 2 | Flash v2.5 advertises ~75 ms model latency; streaming API + websocket support. v3 latency: NOT fit for realtime (per ElevenLabs' own model guidance). |
| Cost vs free tier | 1 | Free: 10,000 credits/mo, NO cloning, no commercial rights. Instant Voice Cloning starts on Starter (≈$5-6/mo, 30,000 credits ≈ 30 min multilingual TTS). Family-call volume (~30 min/week EN output) likely needs Creator ($22/mo) or careful budgeting on Starter. |
| Credential/vendor synergy | 0 | New vendor, new key (`xi-api-key` header). New `buildConfigField` needed. |
| Offline | 0 | Cloud only. |

API notes: `POST /v1/voices/add` (multipart, files=sample) → `voice_id`;
`POST /v1/text-to-speech/{voice_id}?output_format=pcm_16000` with
`{"text","model_id"}`. `pcm_16000` returns RAW headerless PCM at 16 kHz —
in-contract after adding the 44-byte WAV header. Tier-gating of pcm output
formats: **(secondary source — verify on your tier during the spike)**.

Sources: elevenlabs.io/pricing, elevenlabs.io/docs/overview/models,
help.elevenlabs.io "What languages do you support?",
elevenlabs.io/blog/voice-cloning-in-12-indian-languages-demonstrated-live-at-iit-delhi,
elevenlabs.io/blog/meet-flash.

## 2. GCP Cloud TTS — Chirp 3 HD stock voices (non-cloned)

| Axis | Score | Evidence (2026-07-13) |
| :--- | :--- | :--- |
| EN cloned output | 0 | Stock voices only — no cloning. |
| GU cloned output | 0 (but 1 for "GU output at all") | Chirp 3 HD locales include `gu-IN` (8 speakers across 31 new locales per release notes). Identity-lite: a pleasant Gujarati voice that is NOT grandma's. |
| Chunk-4 latency fit | 2 | Streaming synthesis supported; Google infra. |
| Cost vs free tier | 2 | Chirp 3 HD free tier 1M chars/month, then $30/1M **(secondary source for exact split — verify at cloud.google.com/text-to-speech/pricing)**. Family volume ≈ free. |
| Credential/vendor synergy | 2 | Same GCP project as STT + Translation; `texttospeech.googleapis.com/v1/text:synthesize?key=` accepts the existing API-key mechanism (same pattern as `SttService.kt`). Enable "Cloud Text-to-Speech API" in the project — third API on the one key. |
| Offline | 0 | Cloud only. |

API notes: request `audioConfig.audioEncoding=LINEAR16, sampleRateHertz=16000`;
response `audioContent` is base64; decoded LINEAR16 arrives WAV-headered
(verify `RIFF` magic in the spike). Voice names drift — enumerate live via
`GET /v1/voices?key=...&languageCode=gu-IN`.

## 3. GCP Chirp 3 — Instant Custom Voice (real cloning)

| Axis | Score | Evidence (2026-07-13) |
| :--- | :--- | :--- |
| EN cloned output | 2 | ~10 s reference audio builds the clone. |
| GU cloned output | 2 | `gu-IN` IS in the 31-language support list with a localized mandatory consent statement — the only surveyed cloud option with first-party Gujarati cloning. |
| Chunk-4 latency fit | 2 | Streaming synthesize with custom voices documented. |
| Cost vs free tier | 0 | $60/1M characters, no free tier **(secondary source — verify)**. |
| Credential/vendor synergy | 1 | Same GCP project, BUT: (a) **access is allowlist-gated — "contact a member of the sales team"** (docs.cloud.google.com/text-to-speech/docs/chirp3-instant-custom-voice), realistic blocker for a personal project; (b) docs examples authenticate with OAuth bearer tokens, not the simple `?key=` pattern — integration differs from SttService; (c) a spoken consent statement in the fixed Google-provided script is mandatory (grandparent must record it — culturally fine, plan for it). |
| Offline | 0 | Cloud only. |

## 4. AI4Bharat IndicF5 (open weights, self-hosted)

| Axis | Score | Evidence (2026-07-13) |
| :--- | :--- | :--- |
| EN cloned output | 0 | 11 Indian languages only (Assamese, Bengali, **Gujarati**, Hindi, Kannada, Malayalam, Marathi, Odia, Punjabi, Tamil, Telugu) — English not listed. |
| GU cloned output | 2 (unproven quality) | Reference-audio cloning: inputs = target text + reference clip + its transcript. MIT license (huggingface.co/ai4bharat/IndicF5). 0.4B params. |
| Chunk-4 latency fit | 1 | Depends entirely on your inference hardware; no published latency; **unproven**. |
| Cost vs free tier | 1 | Software $0, but hosting = the repo's FIRST backend → full GEMINI.md rule-5 gate (terraform + cost projection) AND activates the Bruno contract-test gate. Local-PC hosting avoids GCP cost but breaks "works when I'm not home". |
| Credential/vendor synergy | 0 | New infra, new ops surface. |
| Offline | 1 | Server-local yes; on-device Android no (0.4B PyTorch model — not a mobile runtime today). |

Best use: the FUTURE child→grandparent leg (English child voice cloned speaking
Gujarati is NOT what IndicF5 does either — it clones a voice and speaks Indic
text; whether an English child's reference produces an acceptable Gujarati clone
is an open research question → voicebridge-research-frontier).

## 5. Device-native Android TextToSpeech

| Axis | Score | Evidence (2026-07-13) |
| :--- | :--- | :--- |
| EN cloned output | 0 | No cloning, ever. |
| GU cloned output | 0 | Stock only; Gujarati availability depends on the installed engine/voice-data (Google Speech Services or Hear2Read third-party engine). Runtime check: `TextToSpeech.isLanguageAvailable(Locale("gu","IN"))`. |
| Chunk-4 latency fit | 2 | On-device, effectively instant. |
| Cost vs free tier | 2 | $0. |
| Credential/vendor synergy | 2 | No credentials at all. |
| Offline | 2 | The only offline option (after voice-data download). |

Role: error-path fallback (network/vendor down → still speak the translation in
a generic voice) and a $0 accessibility floor. Not a Chunk 3 headline.

## 6. Coqui XTTS-v2 (and class) — REJECTED for Chunk 3

- 17 languages; **Gujarati absent** → fails the hard axis outright.
- Weights under Coqui Public Model License (non-commercial only); Coqui Inc.
  shut down January 2024 — no commercial license path, dormant maintenance.
- Needs a GPU server (same infra burden as IndicF5) for a worse language fit.
- Keep on the radar only as "the class of model to re-scan yearly" →
  voicebridge-research-frontier.

## Composite (unweighted sums, 2026-07-13)

| Option | EN | GU | Latency | Cost | Synergy | Offline | Sum |
| :--- | :-: | :-: | :-: | :-: | :-: | :-: | :-: |
| ElevenLabs | 2 | 1 | 2 | 1 | 0 | 0 | 6 |
| Chirp 3 HD (stock) | 0 | 0(1) | 2 | 2 | 2 | 0 | 6–7 |
| Chirp 3 Instant Custom | 2 | 2 | 2 | 0 | 1 | 0 | 7* |
| IndicF5 | 0 | 2 | 1 | 1 | 0 | 1 | 5 |
| Device-native | 0 | 0 | 2 | 2 | 2 | 2 | 8** |

\* highest raw sum but allowlist-gated — unusable until Google grants access;
that is why it ranks 3rd in the SKILL.md menu, not 1st.
\*\* high sum is an artifact of unweighted axes — it scores 0 on BOTH axes that
define Chunk 3 (cloning). The unweighted sum is a sanity check, not the ranking;
the ranking in SKILL.md weights the cloning axes as qualifying criteria.

Maintained by: whoever runs the next Phase 1 refresh. On refresh, copy this file
to `provider-survey-<new date>.md`, update, and repoint SKILL.md — keep old
snapshots for decision archaeology.
