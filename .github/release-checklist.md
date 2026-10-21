### On the test phone (OnePlus 11 5G) before `release.py final`

Install from the Chromebook: download the APK from this pre-release, then `115g install <apk>`.
If the install fails with `INSTALL_FAILED_UPDATE_INCOMPATIBLE`, an older build with another
signing key is installed: `115g run pm uninstall com.mananpatel.voicebridge`, then install again.

- [ ] Settings → Apps → VoiceBridge shows the version of this tag (without `-rc.N`).
- [ ] Allow the microphone, then **Record**, speak, **Stop**, **Play**: you hear yourself clearly.
- [ ] **Transcribe (Gujarati)** on Gujarati speech: Gujarati text appears. This also proves the
      API key's Android restriction accepts this release build (the error would say "blocked").
- [ ] **Translate (English)**: an English translation appears. Typed Gujarati works too.
- [ ] Read the Amdavadi test script (`~/voicebridge-test-script.html`): the slang (કીટલી, લપ,
      હેંડ ને) comes out right in the transcript most of the time.
- [ ] Turn Wi-Fi and mobile data off, tap **Transcribe**: a clear error card, no crash.
