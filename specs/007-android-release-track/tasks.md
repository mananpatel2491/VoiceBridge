# Tasks: Android Release Track (v0.1.0)

Built on branch `v0.1.0`; released as v0.1.0 on 2026-10-21. T001-T009 were done in PR #2,
T010-T012 by the owner, and the two template fixes (T013) in PR #3.

- [X] T001 Gradle: version from `RELEASE_TAG`, CI-only release signing, `.debug` suffix, empty key default (FR-004, FR-005, FR-006)
- [X] T002 Gradle deviation from the runbook snippet: create the release signing config only when `ANDROID_KEYSTORE_PATH` is set (AGP 9.1 refuses a config without `storeFile`)
- [X] T003 Lint as a gate (`abortOnError = true`); fix the existing `MissingPermission` in `AudioRecorder` (FR-006)
- [X] T004 `AndroidClientHeaders.kt`: `X-Android-Package` / `X-Android-Cert` on STT and Translation requests (FR-007)
- [X] T005 `.github/workflows/android-ci.yml`, `android-release.yml` from the platform templates; actionlint clean (FR-002, FR-006)
- [X] T006 `.github/release-checklist.md` (FR-008)
- [X] T007 Vendor the release kit with `--workflow android-release.yml`; pin check and `test_release.py` pass (FR-001)
- [X] T008 Remove the PowerShell gate; update README, CLAUDE.md, PATTERNS.md, constitution, Project_Structure.md, CHANGELOG, skills; mark spec 005 superseded (FR-009)
- [X] T009 Verify locally: `testDebugUnitTest lintDebug assembleDebug`, signed tag build with a throwaway key (SC-002), `release.py rc 0.1.0 --dry-run` (SC-001)
- [X] T010 Owner: keystore, Vaultwarden copies, environment `android-release` with its v* tag policy, the three secrets, `ANDROID_CERT_SHA256` (FR-003)
- [X] T011 Owner: key "VoiceBridge Android" (project mananutils) restricted to both packages + certificate SHA-1s and to the Speech and Translation APIs; per-day quota caps Speech 1200 s, Translation 50,000 characters, granted (FR-007). Checked: requests without the headers or with a wrong certificate are blocked
- [X] T012 Owner: old `com.mananpatel.voicebridge` uninstalled (main and clone profile), rc.3 installed and the checklist passed on the OnePlus 11 5G (SC-003 met), v0.1.0 promoted from rc.3 (byte-identical APK), cleanup done
- [X] T013 Two template bugs found by the first rcs, fixed in VoiceBridge's `android-release.yml` and reported to mananutils-platform: rc.1 failed because AGP 9 has no `testReleaseUnitTest` (fix 25808b3); rc.2 signed correctly but the check couldn't read the newer apksigner output `V2 Signer: certificate SHA-256 digest:` (fix 7a51fbe)
