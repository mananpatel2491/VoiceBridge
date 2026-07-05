# Research: Gujarati→English Translation (Chunk 2)

As-built record — decisions reconstructed 2026-07-05 from v0.0.4, `CHANGELOG.md` [0.0.4]
Decisions block, and `README.md` Key Decisions.

## Decision 1 — GCP Cloud Translation API v2 (over DeepL / Azure / OpenAI)

**Choice**: Cloud Translation v2 with `source=gu`, `target=en`
(`TranslationService.kt:14,32-37`).
**Why**: explicit Gujarati support; **credential reuse** — the same `GCP_STT_API_KEY` covers
Translation once the API is enabled on the same project (zero new setup for the Director);
500K chars/month free tier.
**Rejected** (`README.md:11-19`; `CHANGELOG.md:30-34`):
- DeepL — no Gujarati; eliminated immediately.
- Azure Translator — Gujarati yes, but a separate provider/account/key; no synergy.
- OpenAI GPT-4o — prompt-based translation, higher cost, different provider, no natural
  pairing with GCP STT.

## Decision 2 — v2 (API key) rather than v3 (OAuth)

**Choice**: the legacy-but-supported v2 REST endpoint that accepts `?key=` auth
(`TranslationService.kt:14,40`).
**Why**: v3 requires OAuth/service accounts — infrastructure a personal app doesn't need;
v2 keeps the single-API-key posture established in Chunk 1.
**Rejected**: Translation v3 (`projects.translateText`) — auth complexity without benefit at
this scale.

## Decision 3 — Editable transcript field as the translation input

**Choice**: replace the read-only transcript card with an `OutlinedTextField` that STT fills
but the user can edit or type into directly (`MainActivity.kt:151-163`;
`CHANGELOG.md:19-21`).
**Why**: (a) STT output should be human-verified before being translated for a child;
(b) makes Chunk 2 testable without Chunk 0/1 (type Gujarati, translate) — which the smoke
test exploits by typing "hello" in CI (`android/scripts/smoke-test.ps1:316-327`).
**Rejected**: auto-translate on STT completion (silent error propagation), separate "input
mode" screen (needless navigation).

## Decision 4 — Stale-translation invalidation on edit

**Choice**: `onTranscriptEdited()` clears `translatedText` on every field change
(`MainViewModel.kt:113-117`); `startRecording()` and `transcribe()` also clear it
(`MainViewModel.kt:38-41,80-88`).
**Why**: a displayed translation must always correspond to the displayed transcript — stale
pairs are worse than no translation in a trust-sensitive family context
(`CHANGELOG.md:22`).
**Rejected**: keeping the old translation until the next Translate tap.

## Decision 5 — `format=text` (not HTML)

**Choice**: request plain-text handling (`TranslationService.kt:36`).
**Why**: input is speech transcript; HTML entity escaping (v2's default) would corrupt
apostrophes etc. in the child-facing output.

## Decision 6 — Service-shape symmetry with SttService

**Choice**: identical object/OkHttp/`Result`/error-mining structure as Chunk 1
(`TranslationService.kt` mirrors `SttService.kt`).
**Why**: pattern reuse keeps both seams ready for a common provider-interface extraction
later; error UX is uniform (one error card renders both).
**Rejected**: a shared generic "GcpJsonClient" abstraction now — only two call sites, and
their payloads differ enough that the abstraction would be premature.
