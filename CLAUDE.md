# CLAUDE.md — VoiceBridge

`GEMINI.md` is the constitution of record and applies to Claude sessions too; read it, then
`PATTERNS.md` and `Project_Structure.md`, before changing anything. On conflict, GEMINI.md
wins. Features beyond a trivial fix go through the Spec Kit chain (`/speckit-specify` …) into
`specs/NNN-*/`.

## Dev loop

- Build on the Chromebook (JDK 21, SDK in `~/Android/Sdk`), test on the OnePlus 11 5G over
  wireless adb: `115g vb` builds, installs and launches the debug build
  (`com.mananpatel.voicebridge.debug`). `115g log`, `115g shot`, `115g crash` for evidence.
  Never use the Nexus 6P (10.0.0.40) for app testing: it's the backup Pi-hole.
- Before a PR, run what CI runs: `cd android && ./gradlew testDebugUnitTest lintDebug assembleDebug`.
  Lint errors fail the build.
- Python scripts (`scripts/*.py`) run with the project venv: `.venv/bin/python scripts/verify_structure.py`
  after every change. `.claude/session-setup.sh` creates `.venv`; the system Python has no pip.
- `android/local.properties` (gitignored) holds `sdk.dir` and `GCP_STT_API_KEY`. The owner
  types the key; never print it, put it on a command line or commit it.

## Releases

Android track of the shared process:
https://github.com/mananpatel2491/mananutils-platform/blob/main/docs/release-process.md#android-apps

- Work on branch `vX.Y.Z`, add its CHANGELOG entry, open a PR (template is vendored).
- `python3 scripts/release.py rc X.Y.Z` → signed APK on a GitHub pre-release; the owner installs
  it and works through `.github/release-checklist.md`; merge; `release.py final X.Y.Z`;
  delete the rc pre-releases; `release.py cleanup X.Y.Z`.
- Agents run `release.py` only with `--dry-run`; the owner pushes the tags.
- `scripts/release.py`, `scripts/test_release.py`, `.github/pull_request_template.md` and
  `scripts/release.pin` are vendored: don't edit them here. Change them in mananutils-platform
  and vendor again (`bash scripts/vendor-release.sh ../VoiceBridge` from that clone).
- Version comes from the tag; never hand-edit `versionName` / `versionCode`.
- The API key is restricted to the app's packages and certificates. A new Google API call
  must add the restriction headers with `.androidClient()` (`AndroidClientHeaders.kt`).
