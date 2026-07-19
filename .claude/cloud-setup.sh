#!/usr/bin/env bash
# Cloud environment setup script for claude.ai/code sandboxes.
# Paste `bash .claude/cloud-setup.sh` into the cloud environment's
# setup-script field. Runs ONCE when the environment cache is (re)built
# (snapshot reused ~7 days); never runs in local sessions.
#
# Network allowlist the environment needs: dl.google.com,
# services.gradle.org, maven.google.com, repo.maven.apache.org, pypi.org.
#
# Deliberately NO emulator and NO git hooks: the UI smoke test / release
# gate (android/scripts/install-hooks.ps1 + smoke-test.ps1) stays a
# local-machine step. Cloud sessions verify build + lint only.
set -euo pipefail

# JDK 17 (skip if the sandbox image already has one)
if ! java -version 2>&1 | grep -q '"17\.'; then
  sudo apt-get update && sudo apt-get install -y openjdk-17-jdk-headless
fi

# Android SDK: cmdline-tools + the packages compileSdk 35 needs
export ANDROID_HOME="${ANDROID_HOME:-$HOME/android-sdk}"
if [ ! -d "$ANDROID_HOME/cmdline-tools/latest" ]; then
  mkdir -p "$ANDROID_HOME/cmdline-tools"
  curl -fsSL -o /tmp/clt.zip \
    https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip
  unzip -q /tmp/clt.zip -d "$ANDROID_HOME/cmdline-tools"
  mv "$ANDROID_HOME/cmdline-tools/cmdline-tools" "$ANDROID_HOME/cmdline-tools/latest"
fi
yes | "$ANDROID_HOME/cmdline-tools/latest/bin/sdkmanager" --licenses >/dev/null
"$ANDROID_HOME/cmdline-tools/latest/bin/sdkmanager" \
  "platform-tools" "platforms;android-35" "build-tools;35.0.0"

# Optional pre-warm: bake the Gradle 9.3.1 wrapper + dependency cache into
# the environment snapshot so per-session builds start warm.
if [ -d android ]; then
  (cd android && ./gradlew --console=plain --version) || true
fi
