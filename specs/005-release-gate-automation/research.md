# Research: Release Gate Automation

As-built record — decisions reconstructed 2026-07-05 from v0.0.3, commit 88ac97a, and
`PATTERNS.md` §4–5.

## Decision 1 — Saraswati-pattern local smoke test instead of cloud CI

**Choice**: a single PowerShell script on the dev machine is the whole pipeline
(`Project_Structure.md:69` calls it the "Saraswati-pattern smoke test" — the pattern was
*inspired by* the sibling personal project, implemented fresh here).
**Why**: $0/mo; the emulator and SDK already live on the dev box; a personal app doesn't
justify device-farm minutes; the constitution demands a gate, not a vendor.
**Rejected**: GitHub Actions with a hosted emulator (slow, flaky nested-virtualization,
costs quota; secrets would need to leave the machine).

## Decision 2 — UIAutomator dump + text/content-desc selectors, never pixels

**Choice**: every tap resolves from a live `uiautomator dump` XML by `@text` or
`@content-desc` (`smoke-test.ps1:79-117`); Compose semantics (`enabled`, `contentDescription`)
are the assertion surface (`smoke-test.ps1:128-140`; field tagged at `MainActivity.kt:160`).
**Why**: survives layout shifts and resolution changes; enabled-state assertions come free
because Material3 propagates `enabled` into the accessibility tree.
**Rejected**: hardcoded coordinates (breaks on any layout change); Espresso/instrumented
tests (require a test APK + on-device runner — heavier than needed for a smoke gate, and the
dump approach exercises the installed APK exactly as a user would).
**Cost accepted**: selectors are a manual sync contract with `MainActivity.kt` labels
(`smoke-test.ps1:26`, `PATTERNS.md:42`).

## Decision 3 — CHANGELOG.md update as the release signal

**Choice**: the post-commit hook auto-merges only when the commit on a `vX.Y.Z` branch
touches `CHANGELOG.md` (`hooks/post-commit:22-24`; `PATTERNS.md:34`).
**Why**: releases already require a changelog entry, so the signal is free and
intentional — no magic commit-message tokens; intermediate commits get the smoke test
without merge (`PATTERNS.md:35`).
**Rejected**: tag-triggered release (tags are reserved for the future deploy gate,
`GEMINI.md:33-34`); commit-message markers (easy to fat-finger).

## Decision 4 — post-commit (not pre-commit) hook

**Choice**: the gate runs AFTER the commit lands; a failed run leaves the branch unmergedbut
the commit intact (`hooks/post-commit:36-40`).
**Why**: a 3–5 minute emulator gate inside pre-commit would block every commit and invite
`--no-verify` habits; post-commit keeps commits cheap while making *merges to main* the
protected event.
**Rejected**: pre-commit smoke test (latency), CI-side gating (Decision 1).

## Decision 5 — `-Build` on release runs (fix 88ac97a)

**Choice**: the hook passes `-Build` (fresh `assembleDebug`) when auto-merge is on the line
(`hooks/post-commit:33-34`); intermediate runs reuse the last APK for speed
(`hooks/post-commit:28-29`).
**Why (learned)**: as shipped in v0.0.3 the release path could smoke-test a stale APK and
merge unbuilt changes — fixed during the v0.0.4 cycle (commit 88ac97a "fix: hook now passes
-Build on release commits").
**Rejected**: `-Build` on every intermediate commit (needless minutes per WIP commit).

## Decision 6 — Accumulate failures; crash gate is absolute

**Choice**: `Fail()` appends and continues (`smoke-test.ps1:74`); the summary reports all
issues at once (`smoke-test.ps1:368-375`); but any logcat `FATAL EXCEPTION`/
`E AndroidRuntime` or a backgrounded app fails regardless of UI results
(`smoke-test.ps1:346-359`).
**Why**: one run should surface every broken selector (they usually break in batches after
UI work); crashes are non-negotiable by definition.
**Rejected**: fail-fast (hides subsequent breakage), crash-tolerant "warning" mode.

## Decision 7 — ASCII-only PowerShell, LF-only sh hook

**Choice**: `smoke-test.ps1` is ASCII-only (`smoke-test.ps1:28`); the hook is `#!/bin/sh`
POSIX, LF-only (`hooks/post-commit:1-4`).
**Why (environment-learned)**: Windows PowerShell 5.1 reads unsigned `.ps1` as ANSI —
non-ASCII garbles parsing; Git for Windows executes hooks under sh, and CRLF breaks the
shebang line.
