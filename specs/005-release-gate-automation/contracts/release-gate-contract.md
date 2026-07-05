# Release Gate Contract: smoke test + post-commit hook

The interface every VoiceBridge release passes through. No REST surface — the contract is
CLI exit codes, git signals, and selector obligations.

## Invocation contract

```powershell
powershell -File android/scripts/smoke-test.ps1 [-Build] [-AutoMerge]
           [-AvdName <avd>] [-JavaHome <path>] [-AndroidHome <path>]
```

| Exit code | Meaning |
|---|---|
| 0 | all steps green (and, with `-AutoMerge` on a `vX.Y.Z` branch: merged + pushed; on a non-version branch: merge skipped with warning, still 0 — `smoke-test.ps1:380-384`) |
| 1 | ≥1 accumulated failure, OR build failed, OR APK missing, OR checkout/merge/push failed (`smoke-test.ps1:179,183-186,368-375,389-403`) |

## Step contract (order is binding)

| # | Step | Failure condition |
|---|---|---|
| 0 | credential hygiene + `verify_structure.py` | `local.properties` tracked; structure gate exit ≠ 0 (Python absent → SKIP, not fail) |
| 1 | `assembleDebug` (only with `-Build`) | gradle exit ≠ 0 (hard exit 1) |
| 2 | emulator ensure | (boot poll caps at ~3 min; later steps fail if offline) |
| 3 | install + `pm grant` + launch | element assertions downstream |
| 4 | initial-state matrix | any of: title/5 buttons missing; Record≠on, Stop/Play/Translate≠off |
| 5–6 | record → stop | Stop/Record state flip wrong; Play/Transcribe not enabled after stop |
| 7 | play | (screenshot only) |
| 8 | transcribe | neither transcript nor error card appears |
| 9 | translate | neither translation card nor error card appears |
| 10 | crash gate | any logcat `FATAL EXCEPTION`/`E AndroidRuntime`; app not foreground |

## Git signal contract (hook, `android/scripts/hooks/post-commit`)

| Event | Behavior |
|---|---|
| commit on non-`vX.Y.Z` branch | no-op, exit 0 |
| commit on `vX.Y.Z`, CHANGELOG.md untouched | `smoke-test.ps1` (reuses last APK); exit = smoke exit |
| commit on `vX.Y.Z`, CHANGELOG.md touched | `smoke-test.ps1 -Build -AutoMerge`; on pass: `git checkout main && git merge --no-ff <branch> -m "Merge <branch> into main" && git push origin main && git push origin <branch>`; on conflict: checkout back to `<branch>` |

Post-commit semantics: the commit ALWAYS lands first; the gate governs the merge, not the
commit.

## Selector obligations (owed by the app, consumed by the gate)

- Button labels `Record`, `Stop`, `Play`, and labels containing `Transcribe` and
  `(English)` must remain stable, or the smoke test must be updated in the same change
  (`smoke-test.ps1:26`; `PATTERNS.md:42`).
- The transcript input must keep `contentDescription = "transcript-field"`
  (`MainActivity.kt:160` ↔ `smoke-test.ps1:314`).
- Error surfaces must contain `Error:` (generic), `GCP_STT_API_KEY` (missing key), or
  `Translation API error` (translation HTTP failure) for the no-credential CI paths to
  pass.

## Installer contract

`powershell -File android/scripts/install-hooks.ps1` — copies every file from
`android/scripts/hooks/` into `.git/hooks/` (overwrite), exit 1 only if the template dir is
missing. Required after every fresh clone (`PATTERNS.md:36`).
