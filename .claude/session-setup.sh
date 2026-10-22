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

# 2. Python deps for scripts/*.py, in a project venv (.venv, gitignored). Debian 12+
#    refuses system-wide pip installs (PEP 668), so never use the system pip.
#    No-op when requirements.txt hasn't changed since the last install.
if [ ! -x .venv/bin/python ]; then
  if ! python3 -m venv .venv; then
    rm -rf .venv
    echo "SessionStart: 'python3 -m venv' failed (Debian: install python3-venv); skipped Python deps" >&2
    exit 0
  fi
fi
stamp=".venv/.requirements.sha256"
if ! sha256sum --status -c "$stamp" 2>/dev/null; then
  .venv/bin/python -m pip install -q --disable-pip-version-check -r requirements.txt
  sha256sum requirements.txt > "$stamp"
fi
