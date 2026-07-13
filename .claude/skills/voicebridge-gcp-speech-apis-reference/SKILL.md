---
name: voicebridge-gcp-speech-apis-reference
description: >-
  Load this skill when you need to understand, debug, extend, or test VoiceBridge's two
  Google Cloud API calls — Speech-to-Text v1 (speech:recognize, Gujarati gu-IN) in
  SttService.kt and Cloud Translation v2 (gu->en) in TranslationService.kt. Covers exact
  request/response anatomy, the single-API-key auth model, error signatures (400/403/429),
  free-tier cost limits, the ~60s synchronous STT ceiling, and copy-pasteable PowerShell
  commands to hit either API directly with the key from local.properties. Load it for
  symptoms like "GCP STT error 400/403", "Translation API error", "(No speech detected)",
  "API key not valid", empty transcript, quota questions, or before adding any new
  parameter to either request. Do NOT load it for on-device audio capture/WAV format
  questions (voicebridge-audio-pipeline-reference), build/env/key-injection setup
  (voicebridge-build-and-env), general app debugging (voicebridge-debugging-playbook),
  or Chunk 3 TTS work (voicebridge-chunk3-voice-clone-tts-campaign).
---

# VoiceBridge GCP Speech APIs Reference

How this repo **actually** calls Google Cloud Speech-to-Text v1 and Cloud Translation v2.
Everything below is grounded in the two service files — read them alongside this doc:

- `android/app/src/main/java/com/mananpatel/voicebridge/SttService.kt` (94 lines)
- `android/app/src/main/java/com/mananpatel/voicebridge/TranslationService.kt` (64 lines)

There is **no backend**. The Android app calls both GCP REST APIs directly from the device
over OkHttp. `Function_Mapping.md` is a placeholder reserved for a future backend.

Jargon, defined once:

| Term | Meaning here |
| :--- | :--- |
| STT | Speech-to-Text: audio in, text transcript out |
| LINEAR16 | GCP's name for raw uncompressed PCM 16-bit audio (no container/header) |
| PCM | Pulse-code modulation — the raw sample bytes inside a WAV file |
| `gu-IN` / `gu` | BCP-47 language codes for Gujarati (India). STT v1 wants `gu-IN`; Translation v2 wants bare `gu` |
| API key | A single string credential passed as a URL query parameter (`?key=...`) — this repo does NOT use OAuth, service accounts, or SDKs |
| Synchronous recognize | The `speech:recognize` endpoint: whole audio in one POST, whole transcript in one response |

---

## 1. Auth model — one API key, query param, both APIs

- ONE key, named `GCP_STT_API_KEY`, lives in gitignored `android/local.properties`
  (template: `android/local.properties.template:13`). Despite the "STT" in the name it
  covers **both** APIs — same GCP project, both APIs enabled
  (`TranslationService.kt:24-30` says so explicitly in its error message).
- Injected at build time via `buildConfigField` (`android/app/build.gradle.kts:27-31`),
  read in code as `BuildConfig.GCP_STT_API_KEY` (`MainActivity.kt:32`). Blank key →
  friendly error card, never a crash (`MainViewModel.kt:73-79`, and the smoke test
  asserts exactly this, `PATTERNS.md` §5 "Transcribe Without a Key").
- The key is appended as `?key=$apiKey` to the URL (`SttService.kt:60`,
  `TranslationService.kt:40`). No `Authorization` header, no token refresh, nothing else.

**Key-restriction considerations** (GCP Console → APIs & Services → Credentials):

- Apply **API restrictions** limiting the key to "Cloud Speech-to-Text API" and
  "Cloud Translation API" only. Cheap insurance; changes nothing in code.
- **Application restrictions** ("Android apps": package `com.mananpatel.voicebridge` +
  signing-cert SHA-1) only work if the request carries the Android app identity headers —
  this repo's plain OkHttp calls do NOT send them, so an Android-restricted key will get
  `403` "Requests from this ... are blocked". If you add app restrictions, you must also
  send `X-Android-Package` and `X-Android-Cert` headers. As of 2026-07-13 the repo uses
  an unrestricted-or-API-restricted key and no such headers exist in code.
- Never commit the key. `local.properties` is gitignored; keep it that way.

**Enabling both APIs in one project** (one-time GCP setup):
GCP Console → the project that owns your key → "APIs & Services → Library" → enable
"Cloud Speech-to-Text API" AND "Cloud Translation API". If either is disabled you get a
`403` whose message names the missing API (see §5).

---

## 2. STT request anatomy (`SttService.kt`)

| Item | Value | Source |
| :--- | :--- | :--- |
| Endpoint | `POST https://speech.googleapis.com/v1/speech:recognize?key=<KEY>` | `SttService.kt:28,60` |
| Content-Type | `application/json` | `SttService.kt:61` |
| Timeouts | 30 s connect / **60 s read** (audio upload + recognition can be slow) | `SttService.kt:31-34` |
| `config.encoding` | `"LINEAR16"` | `SttService.kt:50` |
| `config.sampleRateHertz` | `AudioRecorder.SAMPLE_RATE` = **16000** — never hardcode; it must match the recorder | `SttService.kt:51`, `AudioRecorder.kt:29` |
| `config.languageCode` | `"gu-IN"` | `SttService.kt:52` |
| `audio.content` | base64 (`Base64.NO_WRAP` — no line breaks) of the **raw PCM only** | `SttService.kt:46,54-56` |

Critical pre-processing: the WAV file from `AudioRecorder` has a 44-byte header.
`SttService` **strips the first 44 bytes** and sends only raw PCM
(`SttService.kt:29,44-45`), because `LINEAR16` means headerless PCM. If you ever send the
whole WAV as LINEAR16, the header bytes are decoded as audio — expect garbage or an empty
result. (Alternative: GCP also accepts full WAV if you omit `encoding` entirely, but that
is NOT what this repo does — keep the strip.)

Guard: a file of ≤ 44 bytes is rejected client-side as "Recording is empty or too short
to transcribe." (`SttService.kt:40-42`).

Wire shape (what actually goes over HTTPS):

```json
{
  "config": { "encoding": "LINEAR16", "sampleRateHertz": 16000, "languageCode": "gu-IN" },
  "audio":  { "content": "<base64 raw PCM>" }
}
```

### STT response parsing

```json
{ "results": [ { "alternatives": [ { "transcript": "કેમ છો", "confidence": 0.9 } ] } ] }
```

- Take `results[i].alternatives[0].transcript` for every result and join with a single
  space (`SttService.kt:83-91`). GCP splits long audio into multiple `results`; only
  `alternatives[0]` (the top hypothesis) is used.
- **Missing or empty `results` is a VALID response meaning "no speech detected"** — GCP
  returns HTTP 200 with `{}` for silence. The service returns `""`
  (`SttService.kt:78-81`) and the ViewModel renders `"(No speech detected)"`
  (`MainViewModel.kt:95`). Do not treat this as an error; do not "fix" it into one.
- All failures surface as `Result.failure` with a human-readable message; the caller
  decides display (`SttService.kt:22-24` doc comment). Pattern for the whole repo.

---

## 3. Translation request anatomy (`TranslationService.kt`)

| Item | Value | Source |
| :--- | :--- | :--- |
| Endpoint | `POST https://translation.googleapis.com/language/translate/v2?key=<KEY>` | `TranslationService.kt:14,40` |
| Content-Type | `application/json; charset=utf-8` (Gujarati is non-ASCII — keep the charset) | `TranslationService.kt:41` |
| Timeouts | 30 s connect / 30 s read (text is small; no long read needed) | `TranslationService.kt:16-19` |
| Body | `{"q": <text>, "source": "gu", "target": "en", "format": "text"}` | `TranslationService.kt:32-37` |

- `format: "text"` matters: without it v2 defaults to HTML mode and entity-escapes output
  (e.g. `'` → `&#39;`).
- Blank-key guard runs BEFORE the network call with a setup-instruction error message
  (`TranslationService.kt:24-30`) — the smoke test greps UI text for it.

### Translation response parsing

```json
{ "data": { "translations": [ { "translatedText": "How are you" } ] } }
```

Exactly `data.translations[0].translatedText` (`TranslationService.kt:57-61`). Only one
`q` is sent, so only one translation comes back. Note this uses `getJSONObject`/`getString`
(throwing), unlike STT's `opt*` style — a malformed 200 body becomes a
`Result.failure(JSONException)`, which is acceptable.

---

## 4. Cost constraints (constitution-level) — verified in repo docs, date-stamped

GEMINI.md lesson 5 gates every infra-dependent feature on projected cost. The distilled
constitution (`.specify/memory/constitution.md:22`) pins development inside free tiers:

| API | Free tier (as recorded 2026-07-13 — **re-verify against GCP pricing pages, these drift**) | Repo source |
| :--- | :--- | :--- |
| Speech-to-Text v1 | 60 audio-minutes/month | `README.md:35`, `specs/003-gujarati-stt/plan.md:39` |
| Cloud Translation v2 | 500,000 characters/month | `README.md:20`, `specs/004-gujarati-english-translation/research.md:12` |

Practical meaning: development/testing must stay inside these. There is deliberately no
VAD yet, so silence recordings DO consume STT minutes — accepted trade-off, documented in
`specs/003-gujarati-stt/plan.md:103` ("free tier makes silence upload cost-neutral at
personal-app scale"). If usage patterns change (Chunk 4 real-time relay), redo the cost
math before building — that is a GEMINI.md lesson-5 gate, not optional.

---

## 5. Error signatures — what each HTTP status means here

Both services extract `error.message` from the standard GCP error envelope and prefix it
(`"GCP STT error <code>: ..."` at `SttService.kt:68-76`; `"Translation API error <code>: ..."`
at `TranslationService.kt:48-55`). GCP error envelope:

```json
{ "error": { "code": 403, "message": "...", "status": "PERMISSION_DENIED" } }
```

| Signature (typical message fragments) | Meaning | Fix |
| :--- | :--- | :--- |
| `400` "API key not valid. Please pass a valid API key." | Key string is wrong/revoked (yes, invalid key is a 400, not 403) | Recheck `local.properties`, rebuild (key is baked in at build time — editing the file alone changes nothing until reassemble) |
| `400` "Invalid recognition 'config': bad sample_rate" or sample-rate mismatch wording | `sampleRateHertz` doesn't match actual audio | Must be `AudioRecorder.SAMPLE_RATE` (16000); never hardcode a different value |
| `400` "Invalid value at 'audio.content'" / base64 decode error | Broken base64 (e.g. line-wrapped) | Keep `Base64.NO_WRAP` (`SttService.kt:46`) |
| `400` mentioning sync input limit / "audio exceeds duration limit" | Audio too long for synchronous recognize | See §6 |
| `403` "Cloud Speech-to-Text API has not been used in project ... or it is disabled" (analogous for Translation) | API not enabled in the key's project | Enable it (§1); wait a few minutes for propagation |
| `403` "Requests from this Android client application ... are blocked" or "requests from referer ... blocked" | Key restriction rejects the caller | Loosen restriction or send identity headers (§1) |
| `403` / `429` "Quota exceeded" / `RESOURCE_EXHAUSTED` | Free tier or per-minute quota exhausted | Check GCP Console → IAM & Admin → Quotas; wait for reset or stop testing with live audio |
| HTTP 200, empty/no `results` (STT) | No speech detected — NOT an error | Expected for silence; UI shows "(No speech detected)" |
| `Result.failure` with `SocketTimeoutException` | Network/proxy stall past 30/60 s | On the corp network the emulator needs the Netskope root CA installed for TLS to GCP to work at all — cert failure shows as `CertPathValidatorException`, not a timeout |

Exact message strings above are typical GCP wording, not repo-controlled — match loosely.

---

## 6. Size/duration ceiling of synchronous `speech:recognize`

Vendor limits (as of 2026-07-13 — re-verify on the GCP STT quotas page): synchronous
`speech:recognize` accepts roughly **≤ 60 seconds of audio and ≤ 10 MB payload**. For
this repo's format the **duration limit binds first**:

- 16 000 Hz × 2 bytes × 1 channel = 32 000 bytes/s → 60 s ≈ 1.92 MB raw PCM
  (≈ 2.56 MB after base64). Far under 10 MB.
- So: recordings longer than ~1 minute will fail with a `400`. Today's UX (press-record,
  short utterances for a 4-year-old ↔ grandparents exchange) stays well under it.

Beyond 60 s — **future options, NOT implemented as of 2026-07-13, label them candidate**:

1. `speech:longrunningrecognize` — async operation polling; audio > 1 min must be
   uploaded to Google Cloud Storage first (`audio.uri`, not `audio.content`). Adds a GCS
   dependency → triggers the GEMINI.md lesson-5 infra/cost gate (Terraform + cost review).
2. Streaming recognition (gRPC `StreamingRecognize`) — the real answer for Chunk 4's
   real-time relay; also what PATTERNS.md §2 "Streaming-First Design" ultimately demands.
   Not started. Do not claim otherwise.

Related open gaps you will meet in the code (all tracked as `[ ]` in specs; do not
"discover" them as bugs): no `STTProvider`/`TranslationProvider` interfaces extracted yet
(services are singleton `object`s called directly), no VAD gating, no streaming, no
latency-budget rows in `Project_Structure.md`. Extracting the provider interfaces is the
sanctioned first step if you extend either service — via the Spec Kit workflow, not ad hoc.

---

## 7. Testing either API from PowerShell (no app, no emulator)

Use these to isolate "is it the app or the API/key?". The key is read into a variable and
**never echoed** — don't print `$key`, don't paste it into logs or commits.

**Step 0 — load the key from local.properties:**

```powershell
$key = ((Get-Content "C:\Docs\Build\mananUtils\VoiceBridge\android\local.properties") |
  Where-Object { $_ -match '^GCP_STT_API_KEY=' }) -replace '^GCP_STT_API_KEY=',''
if (-not $key -or $key -eq 'your_api_key_here') { Write-Warning "Key not set" }
```

**Test Translation (fast, no audio needed — do this first):**

```powershell
$body  = '{"q":"કેમ છો","source":"gu","target":"en","format":"text"}'
$bytes = [Text.Encoding]::UTF8.GetBytes($body)   # PS 5.1 mangles non-ASCII string bodies; send bytes
$resp  = Invoke-RestMethod -Method Post `
  -Uri "https://translation.googleapis.com/language/translate/v2?key=$key" `
  -ContentType 'application/json; charset=utf-8' -Body $bytes
$resp.data.translations[0].translatedText   # expect: "How are you" (or similar)
```

**Test STT (needs a real recording):** pull the app's last recording off the
emulator/device (debug builds allow `run-as`). Never redirect adb binary output
with `>` in PowerShell 5.1 — it re-encodes native stdout as text and corrupts
the PCM, so the POST below would upload garbage and mislead this whole
isolation test (see voicebridge-diagnostics-and-tooling section 3). Use the
byte-safe two-step route:

```powershell
& C:\Android\platform-tools\adb.exe shell "run-as com.mananpatel.voicebridge cat files/recording.wav > /sdcard/recording.wav"
& C:\Android\platform-tools\adb.exe pull /sdcard/recording.wav "$env:TEMP\recording.wav"
& C:\Android\platform-tools\adb.exe shell rm /sdcard/recording.wav
```

Then replicate exactly what `SttService.kt` does — strip 44 header bytes, base64, POST:

```powershell
$wav = [IO.File]::ReadAllBytes("$env:TEMP\recording.wav")
$pcm = New-Object byte[] ($wav.Length - 44)
[Array]::Copy($wav, 44, $pcm, 0, $pcm.Length)
$req = ('{"config":{"encoding":"LINEAR16","sampleRateHertz":16000,"languageCode":"gu-IN"},' +
        '"audio":{"content":"' + [Convert]::ToBase64String($pcm) + '"}}')
[IO.File]::WriteAllText("$env:TEMP\stt-req.json", $req)
$resp = Invoke-RestMethod -Method Post `
  -Uri "https://speech.googleapis.com/v1/speech:recognize?key=$key" `
  -ContentType 'application/json' -InFile "$env:TEMP\stt-req.json"
($resp.results | ForEach-Object { $_.alternatives[0].transcript }) -join ' '
Remove-Item "$env:TEMP\stt-req.json"   # request file embeds no key, but contains your audio
```

Interpretation: `$resp` with no `results` property = valid "no speech". An error throws in
PowerShell — read the response body with
`$_.ErrorDetails.Message` in a `try/catch` to see the GCP `error.message`, then map it via §5.

Checklist when a device call fails but you're unsure where:

- [ ] Translation curl above succeeds → key + project + Translation API fine
- [ ] STT curl above succeeds → STT API + audio format fine → problem is in-app (see voicebridge-debugging-playbook)
- [ ] Both fail with 403 naming an API → enable that API (§1)
- [ ] Both fail with 400 "API key not valid" → key itself is wrong; fix `local.properties`, then **rebuild the app** (key is compile-time)
- [ ] Works from PowerShell, fails on emulator with `CertPathValidatorException` → corp-proxy CA missing on emulator (install Netskope root CA into the emulator user store)

---

## When NOT to use this skill

| You actually need | Use instead |
| :--- | :--- |
| WAV header layout, AudioRecord/AudioTrack, sample-rate/recording internals | voicebridge-audio-pipeline-reference |
| JDK/SDK/Gradle setup, how the key gets into BuildConfig, build failures | voicebridge-build-and-env |
| App crashes, UI state bugs, logcat triage beyond API errors | voicebridge-debugging-playbook |
| Feature-flag / config surface questions | voicebridge-config-and-flags |
| Release/branch/CHANGELOG/auto-merge mechanics | voicebridge-release-gate-runbook, voicebridge-change-control |
| Architecture rules, provider-interface extraction plan | voicebridge-architecture-contract |
| Voice-clone TTS (Chunk 3) vendor work | voicebridge-chunk3-voice-clone-tts-campaign |
| Smoke test / QA gates | voicebridge-validation-and-qa |
| Past incidents (v0.0.5 manual merge, hook -Build fix) | voicebridge-failure-archaeology |

---

## Provenance and maintenance

Authored 2026-07-13 by skill-distill, grounded line-by-line in the repo at that date.
Re-verify before trusting drift-prone facts:

| Claim | One-line re-verification |
| :--- | :--- |
| STT endpoint/config/timeouts | `Select-String -Path android\app\src\main\java\com\mananpatel\voicebridge\SttService.kt -Pattern 'ENDPOINT|Timeout|LINEAR16|gu-IN|WAV_HEADER'` |
| Translation endpoint/body/timeouts | `Select-String -Path android\app\src\main\java\com\mananpatel\voicebridge\TranslationService.kt -Pattern 'ENDPOINT|Timeout|"source"|"target"|translatedText'` |
| Sample rate 16000 | `Select-String -Path android\app\src\main\java\com\mananpatel\voicebridge\AudioRecorder.kt -Pattern 'SAMPLE_RATE'` |
| Key injection | `Select-String -Path android\app\build.gradle.kts -Pattern 'GCP_STT_API_KEY'` |
| Free-tier numbers (drift!) | Check GCP pricing pages for Speech-to-Text and Cloud Translation; repo statements at `README.md:20,35` |
| Sync recognize 60s/10MB limit (vendor, drift!) | GCP STT "Quotas and limits" docs |
| Provider interfaces still not extracted | `Select-String -Path android\app\src\main\java\com\mananpatel\voicebridge\*.kt -Pattern 'interface (STT|Translation)Provider'` (no hits = still open) |
