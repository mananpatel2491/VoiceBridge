# Quickstart: Release Gate Automation

Prerequisites: Windows, Android SDK at `C:\Android` (or pass `-AndroidHome`), JDK 17, an AVD
named `voicebridge_avd` (or pass `-AvdName`, or have any device/emulator already online).

## 1. Install the hooks (once per clone)

```powershell
cd C:\Docs\Build\mananUtils\VoiceBridge
powershell -File android\scripts\install-hooks.ps1
# Installed: .git/hooks/post-commit
```

## 2. Run the gate manually

```powershell
# Full: build + emulator + UI walk + crash scan (no merge)
powershell -File android\scripts\smoke-test.ps1 -Build

# Faster re-run against the last-built APK
powershell -File android\scripts\smoke-test.ps1
```

Green summary = `SMOKE TEST PASSED` + screenshot dir; red = every accumulated failure listed,
exit 1. Inspect evidence:

```powershell
ls android\app\build\smoke-*   # 01_launch.png … 07_translate-result.png, ui.xml
```

## 3. Exercise the hook routing

```powershell
git checkout -b v9.9.9                         # any vX.Y.Z branch
git commit --allow-empty -m "feat: probe"      # → smoke test only (no -Build, no merge)
# touch CHANGELOG.md in a commit               # → -Build -AutoMerge: merge --no-ff + push on pass
git checkout main; git branch -D v9.9.9        # clean up the probe
```

On any non-version branch the hook exits silently.

## 4. Break it on purpose (selector contract demo)

Rename the `Record` button text in `MainActivity.kt`, rebuild, run the smoke test — it fails
with `could not find UI element: Record button (@text='Record')`. This is the
KEEP-IN-SYNC contract working as designed. Revert afterwards.

## Notes

- The release flow (`-AutoMerge`) pushes `main` AND the version branch to `origin` on pass —
  make sure that is intended before committing CHANGELOG.md on a version branch.
- If Python is not on PATH, the structure-gate step reports SKIP; install Python to restore
  the full gate.
