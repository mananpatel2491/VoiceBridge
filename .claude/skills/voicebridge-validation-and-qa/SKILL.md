---
name: voicebridge-validation-and-qa
description: >
  VoiceBridge evidence and QA doctrine: what counts as PROOF that a change works, the
  acceptance thresholds a version must clear, the inventory of existing gates (smoke test,
  per-chunk README acceptance tests, verify_structure.py docs gate, logcat crash gate,
  dormant Bruno rule), and step-by-step runbooks for extending the tests. Load this skill
  whenever you are about to claim a change is "done", "working", or "shippable"; when
  deciding whether existing tests actually cover a new behavior; when adding NEW test
  coverage — a new smoke-test step, assertion, or per-chunk README acceptance test — for
  new behavior; or when asked what the smoke test does and does not cover. Do NOT load it
  for: running or debugging a failing release (voicebridge-release-gate-runbook),
  diagnosing a live crash or emulator problem (voicebridge-debugging-playbook),
  build/JDK/SDK environment setup (voicebridge-build-and-env), or editing
  constitution/docs files (voicebridge-docs-and-writing or voicebridge-change-control).
---

# VoiceBridge Validation and QA

This skill defines what counts as **evidence** in the VoiceBridge repo, the acceptance
thresholds, the current test inventory, and how to extend the tests safely. It is the
successor's yardstick: if you cannot point to evidence as defined here, the change is not
done — no matter how good the diff looks.

Jargon used once, defined once:

| Term | Meaning |
| :--- | :--- |
| **Smoke test** | `android/scripts/smoke-test.ps1` — a PowerShell script that builds, installs, and drives the app on an emulator via UIAutomator, asserting UI state at each step. |
| **UIAutomator dump** | `adb shell uiautomator dump` — writes the live screen's accessibility tree as XML; the smoke test finds elements in that XML by text/content-desc, never by pixel coordinates. |
| **Chunk** | A shippable stage of the app (Chunk 0 record/play → 1 STT → 2 translation → 3 voice-clone TTS → 4 real-time relay). |
| **Acceptance test** | The manual per-chunk checklist in `README.md` that defines when a chunk counts as built. |
| **Crash gate** | The unconditional logcat scan for `FATAL EXCEPTION` / `E AndroidRuntime` at the end of every smoke run. |
| **Bruno** | An API contract-testing tool. VoiceBridge has a `bruno/` directory and a binding commit rule, but no backend exists yet, so the rule is dormant. |
| **KEEP-IN-SYNC contract** | The rule that smoke-test selectors and `MainActivity.kt` label strings must change together (flagged by `KEEP IN SYNC` comments in both the script and `PATTERNS.md`). |

## 1. The evidence bar (read this first)

A change is **proven** when BOTH of these hold:

1. The full smoke test passes: `powershell -File android/scripts/smoke-test.ps1 -Build`
   exits 0. Per `PATTERNS.md:41`, this single command is "the authoritative definition of
   'done' for a version."
2. The **specific new behavior has its own assertion** — either a new smoke-test step that
   fails when the behavior is broken, or (for a new chunk) a README acceptance test that
   was actually executed and passed.

**Passing-because-untested does not count.** A green smoke run proves only what the smoke
test asserts. If you added a feature and did not add an assertion for it, the smoke test's
PASS is evidence about the *old* behaviors, not the new one. Before claiming done, ask:
"if my feature were silently broken, which line of the smoke test would go red?" If the
answer is "none", write that assertion first (Section 8).

Corollary: screenshots in `android/app/build/smoke-<timestamp>/` (gitignored) are the
primary *diagnostic* artifact (`PATTERNS.md:43`), not the primary *evidence* — a human
glancing at a screenshot is weaker than a script assertion that fails loudly.

## 2. Acceptance thresholds — what a version must clear

| Gate | Command / trigger | Threshold | Blocking? |
| :--- | :--- | :--- | :--- |
| Smoke test | `powershell -File android/scripts/smoke-test.ps1 -Build` | Exit 0, zero entries in the internal `$Failures` list | YES — releases cannot merge without it (post-commit hook runs it on every version-branch commit) |
| Crash gate (inside smoke) | logcat scan, `smoke-test.ps1:346-359` | Zero `FATAL EXCEPTION` / `E AndroidRuntime` lines AND app still foreground | YES — unconditional; there is no waiver |
| Docs gate | `python scripts/verify_structure.py` (also run as smoke pre-flight, `smoke-test.ps1:163-172`) | Every non-excluded file appears in the `Project_Structure.md` Changelog "Files Affected" column | YES when Python is on PATH; smoke prints `SKIP` (not fail) when Python is absent — do not rely on that loophole |
| Credential hygiene (inside smoke) | `git ls-files android/local.properties`, `smoke-test.ps1:156-161` | File must NOT be tracked | YES |
| Per-chunk acceptance test | Manual checklist in `README.md` | Every step observed working on a real device/emulator | YES for shipping a chunk — `.specify/memory/constitution.md:27`: "A chunk ships only when its acceptance test in `README.md` passes." (Distillation of GEMINI.md's chunked-delivery intent; GEMINI.md wins on conflict.) |
| Bruno | none today | n/a | DORMANT — see Section 7 |
| Android lint | runs during build | **Informs, does not gate** — `abortOnError=false` (specs/005 T013: "lint informs, smoke test gates") | NO |

There are no unit tests and no instrumentation-test source sets in the app as of
2026-07-13 — the smoke test's end-to-end UI drive is the entire automated suite. Treat any
statement like "the tests pass" as meaning exactly: *the smoke test passed*.

## 3. The smoke test — authoritative definition of done

Single command gate (from `PATTERNS.md:41`):

```powershell
cd C:\Docs\Build\mananUtils\VoiceBridge
powershell -File android/scripts/smoke-test.ps1 -Build
```

Flags: `-Build` runs `assembleDebug` first (omit for a fast re-run against the last APK);
`-AutoMerge` additionally merges the version branch to `main` and pushes on pass — it is
invoked by the post-commit hook on CHANGELOG-updating commits, and you should not pass it
by hand outside the release flow (that flow belongs to voicebridge-release-gate-runbook).
`-AvdName`, `-JavaHome`, `-AndroidHome` parameterize the machine config (defaults:
`voicebridge_avd`, Eclipse Adoptium JDK 17, `C:\Android` — `smoke-test.ps1:50-52`).

Full stage-by-stage anatomy, timings, and exit codes: **voicebridge-release-gate-runbook
section 2** — do not maintain a second copy here. For evidence purposes the run
comprises: pre-flight (credential hygiene + `verify_structure.py`), optional build,
emulator, install+launch, the UI drive with per-step screenshots (initial-state matrix,
Record→Stop→Play walk, Transcribe and Translate steps that each accept result-card OR
error-card — Section 4), and the unconditional crash gate (Section 5). Failures
ACCUMULATE — the script keeps walking after a failed assertion, so read the whole
failure list, not just the first line.

Screenshot-per-step goes to `android/app/build/smoke-<timestamp>/` along with the pulled
`ui.xml` dumps.

## 4. The error-card-not-crash principle

Deliberate design, not an accident: the smoke test taps **Transcribe without a real API
key** and asserts that an *error card* appears rather than a crash (`PATTERNS.md:45`,
`smoke-test.ps1:278-303`). `GCP_STT_API_KEY` is blank by default in CI-like runs, so:

- If a key IS configured: a transcript card is accepted.
- If NO key: the error card containing the literal string `GCP_STT_API_KEY` is accepted
  (produced by `MainViewModel.kt:76` — "GCP_STT_API_KEY is not set. See
  local.properties.template.").
- If NEITHER appears: the step FAILS.

This means **error surfacing is itself regression-tested, without needing credentials**.
The same pattern applies to the Translate step (`smoke-test.ps1:332-341`). When you build
any future network-touching feature, preserve this property: the no-credential path must
render a visible error card, and the smoke step must accept "correct result OR error card"
— either outcome proves the flow fires and does not crash. A feature whose failure mode is
a silent no-op or a crash violates this principle and will (respectively) evade or fail
the gate.

## 5. The crash gate — unconditional

`smoke-test.ps1:346-359`:

```powershell
$crashes = Adb logcat -d | Select-String -Pattern "FATAL EXCEPTION|E AndroidRuntime"
```

- Any match fails the run, **no exceptions and no waiver string** — unlike Bruno, there is
  no sanctioned bypass for the crash gate.
- logcat is cleared (`logcat -c`) right before app launch (`smoke-test.ps1:209`), so the
  scan covers exactly the test session.
- A second check asserts the app is still the `topResumedActivity` — a crash that Android
  silently restarts, or an unexpected activity switch, also fails.

## 6. What the smoke test does NOT cover (known, recorded gaps)

These are ACCEPTED gaps recorded as open tasks in
`specs/005-release-gate-automation/tasks.md` — recorded "so it is a choice, not an
oversight". Do not claim coverage for any of them, and do not silently fix them without a
version branch and change-control (see voicebridge-change-control):

| Gap | Task | Detail |
| :--- | :--- | :--- |
| Rotation, process death, backgrounding, permission revocation | `[ ] T016` | Smoke test is a happy-path UI walk only. Mid-call audio focus / interruption scenarios are likewise untested. Accepted at personal-app scale. |
| Fragile transcript detection | `[ ] T017` | Transcribe-result detection relies on `contains(@text,'Transcript')` (`smoke-test.ps1:292`) matching the "Transcription complete." status line (`MainViewModel.kt:96`). If that status copy changes, the smoke test can misreport. Recorded fix candidate: a dedicated content-desc like the transcript field's `transcript-field`. |
| Unconditional push | `[ ] T018` | On a release pass the script pushes to `origin` with no offline mode — an unreachable origin fails the release run. (Release-flow concern; owned by voicebridge-release-gate-runbook.) |
| Real STT/translation accuracy | — | With no API key, the GCP calls never succeed in CI; transcription/translation *quality* is only verified by the manual per-chunk acceptance tests with a real key. |

If your change touches any of these areas, the smoke test passing tells you nothing about
it — apply the evidence bar (Section 1) and test manually or extend the script.

## 7. Docs gate: verify_structure.py, and dormant Bruno

### verify_structure.py (`scripts/verify_structure.py`)

```powershell
python C:\Docs\Build\mananUtils\VoiceBridge\scripts\verify_structure.py
```

- **What it checks**: every file under the repo root must appear in the "Files Affected"
  column (column index 3) of the `## Changelog` table in `Project_Structure.md`. Missing
  files → exit 1 with a list; the smoke test then fails pre-flight.
- **What it EXCLUDES**: see the exclusion list in voicebridge-docs-and-writing
  section 2.3, or read it live via
  `Select-String -Path scripts\verify_structure.py -Pattern "startswith|rel_path.parts"`.
- Practical consequence: **adding any new tracked file outside those exclusions requires a
  matching Changelog row in `Project_Structure.md` in the same commit**, or the next smoke
  run fails. (Files in this skill's own `.claude/skills/` tree are excluded — no row
  needed.)
- One-directional check: it flags real files missing from the table, and does NOT flag
  table rows for deleted files ("ghost rows" — a v0.0.7 cleanup theme). Ghost rows are a
  docs-quality issue for voicebridge-docs-and-writing.

### Bruno — binding rule, currently dormant

`GEMINI.md` Lesson 4 makes Bruno validation a commit gate for **backend API features**.
As of 2026-07-13 there is NO backend — the app calls GCP REST APIs directly from the
device, `Function_Mapping.md` is a reserved placeholder, and `bruno/collections/` and
`bruno/docs/` contain only `.gitkeep` files. So the gate has nothing to run and is
dormant. The rule itself stays binding:

- The moment a first backend endpoint exists, every API-exposed function needs a Bruno
  script before its commit is complete (`PATTERNS.md:10`, `bruno/README.md`).
- The ONLY sanctioned exception is a commit message containing the exact string:
  `I understand bruno validation is failing and I allow the exception to have the code committed to github repo`
  (`PATTERNS.md:10`, `GEMINI.md` Lesson 4). Do not paraphrase it; do not invent other
  bypasses. This string is the single sanctioned exception mechanism in the whole repo.

## 8. Runbook: adding a smoke-test step

Use this when a change adds new user-visible behavior. Never assert on pixels; always
assert on `@text` or `@content-desc` from the UIAutomator dump (`PATTERNS.md:42`).

**Helper functions available in `smoke-test.ps1`** (define nothing new unless you must):

| Helper | Location | Use |
| :--- | :--- | :--- |
| `Get-Ui` | line 79 | Fresh UIAutomator dump as `[xml]`; auto-dismisses transient ANR dialogs. Call it again after every tap — dumps go stale. |
| `Get-Center $ui "<xpath predicate>"` | line 101 | Center coordinates of the first matching node, or `$null`. |
| `Tap-Element "<predicate>" "<label>"` | line 111 | Dump + find + tap; records a `Fail` and returns `$false` if not found. |
| `Assert-Node $ui "<predicate>" "<label>"` | line 120 | Presence assertion. |
| `Assert-Enabled $ui "<exact text>" $true/$false` | line 131 | Compose Material3 propagates `enabled` into the accessibility node, so the dump reflects it. Requires an EXACT `@text` match. |
| `Save-Shot "<name>"` | line 142 | Numbered screenshot into the run's output dir. |
| `Fail "<message>"` | line 74 | Accumulates a failure; does NOT stop the script. |

**Steps:**

1. Pick the selector from the Compose source, not from memory. Ground truth for labels is
   `android/app/src/main/java/com/mananpatel/voicebridge/MainActivity.kt` — current set
   (verified 2026-07-13): `"Record"` (line 115), `"Stop"` (120), `"Play"` (126),
   `"Transcribe (Gujarati)"` (147, shows `"Transcribing..."` while busy),
   `"Translate (English)"` (183, shows `"Translating..."` while busy), transcript field
   `contentDescription = "transcript-field"` (160), result card label
   `"Translation (English)"` (190), title `"VoiceBridge"` (70).
2. Prefer a stable `contentDescription` (added via
   `Modifier.semantics { contentDescription = "..." }` as at `MainActivity.kt:160`) for
   anything you will assert on — that is exactly the T017 lesson: free-text status copy
   changes, content-descs are contracts. Match with
   `"@content-desc='your-desc'"`.
3. For buttons whose label changes while busy (Transcribe/Translate), match with
   `contains(@text,'...')` on the stable fragment, as the script does with
   `contains(@text,'Transcribe')` (line 285) and `contains(@text,'(English)')` (line 328).
4. Write the step in the script's existing shape:

   ```powershell
   Log "Testing <feature>..."
   [void](Tap-Element "@content-desc='my-button'" "My button")
   Start-Sleep -Seconds 2          # give Compose + network time; existing steps use 1-3s
   $ui = Get-Ui                    # ALWAYS re-dump after interaction
   Assert-Node $ui "contains(@text,'Expected result')" "my feature result"
   Save-Shot "my-feature"
   Log ""
   ```

5. If the step exercises a network call, follow Section 4: accept
   `result card OR error card`, fail only when neither appears.
6. **ASCII only** — the script header warns: Windows PowerShell 5.1 reads `.ps1` as ANSI;
   non-ASCII characters break parsing (`smoke-test.ps1:28`). No Gujarati literals in the
   script; type ASCII test input (the Translate step types `hello`).
7. Add a `KEEP IN SYNC` comment next to any hardcoded label/string, naming the Kotlin
   source of truth — matching the existing comments at `smoke-test.ps1:26, 130, 225, 283,
   311`.
8. Run the full suite (`-Build`) and then deliberately break your feature (or its
   selector) once to confirm the new step actually goes red. An assertion that cannot fail
   is not evidence.

## 9. Runbook: adding a new button (KEEP-IN-SYNC set)

The selector<->source contract table (and the rename checklist) lives in
**voicebridge-release-gate-runbook section 3**; this checklist covers only the
NEW-coverage additions when `MainActivity.kt` gains a button/screen — the smoke test
MUST change in the same commit (`PATTERNS.md:42`):

- [ ] Give the composable a stable `@text` label (and a `contentDescription` if the label
      is dynamic or duplicated).
- [ ] Add an `Assert-Node` for it in the initial-screen block (`smoke-test.ps1:215-238`).
- [ ] Add `Assert-Enabled` rows for its initial state AND for each state transition it
      participates in — mirror how Record/Stop/Play flips are asserted at lines 226-228,
      247-248, 258. The initial-state block carries its own KEEP-IN-SYNC note pointing at
      `UiState` defaults in `MainViewModel.kt` (line 225) — keep expected states in sync
      with that file, not with your intent.
- [ ] If tapping it triggers behavior, add a step per Section 8.
- [ ] Renaming an existing label? Follow the KEEP-IN-SYNC checklist in
      voicebridge-release-gate-runbook section 3 instead of this one.
- [ ] Run the smoke test; also update `README.md`'s structure sketch if the UI surface
      list there ("Record / Stop / Play / Transcribe / Translate") changed.

## 10. Runbook: adding a per-chunk acceptance test to README

The constitution distillation binds chunks to README acceptance tests
(`.specify/memory/constitution.md:27`). The three existing tests, quoted verbatim from
`README.md` (verified 2026-07-13), are the format template:

**Chunk 0** (`README.md:115-121`):

> 1. Launch the app on your phone.
> 2. Grant microphone permission when prompted.
> 3. Tap **Record**, say something, tap **Stop**.
> 4. Tap **Play** — you should hear the playback clearly.

**Chunk 1** (`README.md:141-147`):

> 1. Record yourself speaking Gujarati, tap Stop.
> 2. Tap **Transcribe (Gujarati)**.
> 3. A Gujarati transcript appears in the editable text field.
> 4. If the key is missing or invalid, a clear error card appears (no silent failure).

**Chunk 2** (`README.md:148-155`):

> 1. Complete the Chunk 1 acceptance test so the transcript field has Gujarati text.
> 2. Tap **Translate (English)**.
> 3. An English translation appears in the card below.
> 4. You can also skip recording: type or paste Gujarati text directly into the transcript field and tap Translate.
> 5. If the key is missing or `Cloud Translation API` is not enabled in the GCP project, a clear error card appears.

When shipping Chunk 3 or 4, write the acceptance test in this exact style **before**
implementation finishes:

1. Numbered, imperative, human-executable steps on a real device — each step observable
   with eyes/ears, no debugger required.
2. At least one step asserting the SUCCESS output (heard/seen), and — mandatory — one
   step asserting the FAILURE surface: "if <credential/config> is missing, a clear error
   card appears (no silent failure)". Every shipped chunk's test has this; keep the
   streak.
3. State the preconditions by referencing the prior chunk's test (as Chunk 2 step 1 does).
4. Place it in `README.md` next to the other acceptance tests, update the Chunk Status
   table (`README.md:69-75`), and mirror whatever is automatable into a smoke-test step
   (Section 8). The README test is the human threshold; the smoke step is the regression
   lock. A chunk needs both.
5. Note that README.md edits appear in the `Project_Structure.md` changelog per the docs
   rules (voicebridge-docs-and-writing owns the wording conventions).

## 11. When NOT to use this skill

| You are trying to… | Use instead |
| :--- | :--- |
| Run/repair a release: version branch, CHANGELOG signal, post-commit hook, auto-merge, push failures | **voicebridge-release-gate-runbook** |
| Debug a red smoke run, crash, emulator boot, or app misbehavior | **voicebridge-debugging-playbook** |
| Understand a past incident (v0.0.5 manual-merge bypass, hook `-Build` fix 88ac97a) | **voicebridge-failure-archaeology** |
| Set up JDK/SDK/Gradle/AVD or fix build errors | **voicebridge-build-and-env** |
| Change what may be changed and how (branch rules, constitution precedence, Director approval) | **voicebridge-change-control** |
| Edit GEMINI.md / PATTERNS.md / Project_Structure.md / CHANGELOG.md conventions | **voicebridge-docs-and-writing** |
| Understand module boundaries, provider interfaces, pipeline stages | **voicebridge-architecture-contract** |
| WAV/PCM format details or GCP STT/Translation API payloads | **voicebridge-audio-pipeline-reference** / **voicebridge-gcp-speech-apis-reference** |
| API keys, buildConfigField, local.properties | **voicebridge-config-and-flags** |
| adb/logcat/uiautomator tooling beyond what this skill quotes | **voicebridge-diagnostics-and-tooling** |
| Plan or build Chunk 3 | **voicebridge-chunk3-voice-clone-tts-campaign** |
| Evaluate new STT/TTS/streaming technology | **voicebridge-research-frontier** |

This skill owns: the evidence bar, the acceptance thresholds, the gate inventory, and the
how-to-extend-the-tests runbooks.

## 12. Provenance and maintenance

Authored 2026-07-13 by skill-distill. All line numbers, quotes, and command flags verified
against the working tree on that date. Re-verify before trusting anything volatile:

| Claim | Re-verification command (PowerShell, from repo root) |
| :--- | :--- |
| Smoke gate wording + KEEP-IN-SYNC + error-card patterns | `Select-String -Path PATTERNS.md -Pattern "Single Command Gate","KEEP SELECTORS","Transcribe Without a Key"` |
| Smoke helper/assertion line numbers | `Select-String -Path android\scripts\smoke-test.ps1 -Pattern "function Get-Ui","function Assert-Enabled","FATAL EXCEPTION","KEEP IN SYNC"` |
| Button labels / content-descs | `Select-String -Path android\app\src\main\java\com\mananpatel\voicebridge\MainActivity.kt -Pattern "Text\(\`"","transcript-field"` |
| No-key error string + status line | `Select-String -Path android\app\src\main\java\com\mananpatel\voicebridge\MainViewModel.kt -Pattern "GCP_STT_API_KEY","Transcription complete"` |
| verify_structure.py exclusions | `Select-String -Path scripts\verify_structure.py -Pattern "specify","android/.gradle"` |
| Open gaps T016-T018 still open (`[ ]`) | `Select-String -Path specs\005-release-gate-automation\tasks.md -Pattern "T016","T017","T018"` |
| README acceptance tests unchanged | `Select-String -Path README.md -Pattern "acceptance test"` |
| Bruno still dormant (only .gitkeep files) | `Get-ChildItem -Recurse bruno\collections, bruno\docs` |
| Constitution chunk-ship rule | `Select-String -Path .specify\memory\constitution.md -Pattern "acceptance test"` |

If any check disagrees with this document, the repo wins — update this SKILL.md, not your
memory of it. On any rule conflict, `GEMINI.md` wins over everything, including this skill.
