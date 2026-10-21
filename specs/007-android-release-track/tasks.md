# Tasks: Android Release Track (v0.1.0)

Built on branch `v0.1.0`. `[X]` done in the PR; `[ ]` owner steps (secrets, GCP, tags).

- [X] T001 Gradle: version from `RELEASE_TAG`, CI-only release signing, `.debug` suffix, empty key default (FR-004, FR-005, FR-006)
- [X] T002 Gradle deviation from the runbook snippet: create the release signing config only when `ANDROID_KEYSTORE_PATH` is set (AGP 9.1 refuses a config without `storeFile`)
- [X] T003 Lint as a gate (`abortOnError = true`); fix the existing `MissingPermission` in `AudioRecorder` (FR-006)
- [X] T004 `AndroidClientHeaders.kt`: `X-Android-Package` / `X-Android-Cert` on STT and Translation requests (FR-007)
- [X] T005 `.github/workflows/android-ci.yml`, `android-release.yml` from the platform templates; actionlint clean (FR-002, FR-006)
- [X] T006 `.github/release-checklist.md` (FR-008)
- [X] T007 Vendor the release kit with `--workflow android-release.yml`; pin check and `test_release.py` pass (FR-001)
- [X] T008 Remove the PowerShell gate; update README, CLAUDE.md, PATTERNS.md, constitution, Project_Structure.md, CHANGELOG, skills; mark spec 005 superseded (FR-009)
- [X] T009 Verify locally: `testDebugUnitTest lintDebug assembleDebug`, signed tag build with a throwaway key (SC-002), `release.py rc 0.1.0 --dry-run` (SC-001)
- [ ] T010 Owner: keystore, Vaultwarden copies, environment `android-release` with its v* tag policy, secrets, `ANDROID_CERT_SHA256` (FR-003)
- [ ] T011 Owner: restrict the API key and cap the quota (FR-007)
- [ ] T012 Owner: uninstall the old `com.mananpatel.voicebridge` from the phone once, push the branch's rc tag, install, run the checklist (SC-003), merge, `final`, cleanup
