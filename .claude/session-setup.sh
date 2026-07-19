#!/usr/bin/env bash
# Per-session setup — cheap and idempotent. Runs at every Claude Code session
# start, LOCAL and CLOUD (SessionStart hook in .claude/settings.json).
# Heavy one-time installs (JDK, Android SDK) do NOT belong here — they go in
# the cloud environment's setup script (.claude/cloud-setup.sh), whose result
# is snapshot-cached.
set -euo pipefail
cd "$(dirname "$0")/.."

# 1. Gitignored build config: generate from env vars only if absent.
#    Cloud sandboxes start without it; local machines have a hand-written
#    one that must never be touched.
if [ ! -f android/local.properties ]; then
  : "${ANDROID_HOME:=${ANDROID_SDK_ROOT:-$HOME/android-sdk}}"
  {
    echo "sdk.dir=$ANDROID_HOME"
    echo "GCP_STT_API_KEY=${GCP_STT_API_KEY:-}"
  } > android/local.properties
  echo "SessionStart: generated android/local.properties (sdk.dir=$ANDROID_HOME)"
fi

# 2. Python deps for scripts/*.py — fast no-op when already satisfied.
python3 -m pip install -q -r requirements.txt 2>/dev/null \
  || python -m pip install -q -r requirements.txt
