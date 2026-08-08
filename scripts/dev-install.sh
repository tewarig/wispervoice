#!/usr/bin/env bash
# Dev install with auto-incrementing build name.
#
# Each run produces wisperflowNN.app (NN = incrementing counter in scripts/.dev-build-number),
# REMOVES every older wisperflow*/WisperVoice copy from /Applications, and installs exactly
# one app — so the newest build is always the only one on disk, and its name tells you which
# build it is (also shown in the menu bar popover footer).
#
# The bundle identifier stays FIXED at com.wispervoice.dev across builds — bundle-id churn is
# what created the pile of duplicate permission rows in System Settings. Only the product
# name (file name / CFBundleName) carries the counter, via an xcodebuild override; nothing
# in the repo is modified per build.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
COUNTER_FILE="$ROOT/scripts/.dev-build-number"
DERIVED="/tmp/wisper_build2"

N=$(( $(cat "$COUNTER_FILE" 2>/dev/null || echo 2) + 1 ))
NAME=$(printf "wisperflow%02d" "$N")

echo "==> Building $NAME (build $N)…"
xcodebuild build \
  -project "$ROOT/WisperVoice.xcodeproj" \
  -scheme WisperVoice \
  -derivedDataPath "$DERIVED" \
  -quiet \
  PRODUCT_NAME="$NAME"

APP="$DERIVED/Build/Products/Debug/$NAME.app"
[ -d "$APP" ] || { echo "Build product not found: $APP" >&2; exit 1; }

# Stamp the build number into the bundle, then re-sign (plist edit invalidates the seal).
plutil -replace CFBundleVersion -string "$N" "$APP/Contents/Info.plist"
codesign --force -s - "$APP"

echo "==> Removing older installs…"
for old in /Applications/wisperflow*.app /Applications/WisperVoice.app; do
  [ -e "$old" ] || continue
  base="$(basename "${old%.app}")"
  osascript -e "tell application \"$base\" to quit" >/dev/null 2>&1 || true
  sleep 1
  rm -rf "$old"
  echo "    removed $old"
done

cp -R "$APP" "/Applications/$NAME.app"
echo "$N" > "$COUNTER_FILE"
open "/Applications/$NAME.app"

echo "==> Installed /Applications/$NAME.app (build $N) and launched it."
echo "    NOTE: the debug build is ad-hoc signed, so its signature changes every build —"
echo "    macOS may ask you to re-grant Accessibility after installing a new build."
