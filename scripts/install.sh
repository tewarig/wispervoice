#!/usr/bin/env bash
# WisperVoice one-line installer:
#   curl -fsSL https://raw.githubusercontent.com/tewarig/wispervoice/main/scripts/install.sh | bash
#
# Why this exists: browser downloads get macOS's quarantine flag, and un-notarized
# apps then show a "malware" warning. curl downloads are never quarantined, so this
# path installs and opens cleanly with no warning and no paid Apple account.
set -euo pipefail

REPO="tewarig/wispervoice"
ZIP_URL="https://github.com/${REPO}/releases/latest/download/WisperVoice-macOS.zip"
DEST="/Applications/WisperVoice.app"

echo "→ Downloading the latest WisperVoice release…"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
curl -fsSL -o "$TMP/WisperVoice.zip" "$ZIP_URL"

echo "→ Installing to /Applications…"
# ditto preserves the code signature exactly (unzip can subtly break bundles)
ditto -x -k "$TMP/WisperVoice.zip" "$TMP"
# Only remove the existing install once the download provably contains the app —
# otherwise a bad/renamed release asset would delete a working install and then fail.
if [ ! -d "$TMP/WisperVoice.app" ]; then
  echo "Download did not contain WisperVoice.app — aborting (existing install untouched)." >&2
  exit 1
fi
rm -rf "$DEST"
ditto "$TMP/WisperVoice.app" "$DEST"
# Defensive: harmless if the flag was never set
xattr -d com.apple.quarantine "$DEST" 2>/dev/null || true

echo "→ Installed. Launching…"
open "$DEST"
echo ""
echo "WisperVoice is running. Grant Microphone and Accessibility when prompted"
echo "(System Settings → Privacy & Security), then press ⌥ Space anywhere to dictate."
