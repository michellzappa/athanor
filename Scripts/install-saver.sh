#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

xcodegen generate
xcodebuild -project Athanor.xcodeproj -scheme AthanorSaver \
  -configuration Release -derivedDataPath build build

DEST="$HOME/Library/Screen Savers"
mkdir -p "$DEST"

# The screen saver host keeps the old bundle mapped; it has to go first.
pkill -f legacyScreenSaver >/dev/null 2>&1 || true

rm -rf "$DEST/Athanor.saver"
cp -R build/Build/Products/Release/Athanor.saver "$DEST/"

echo "Installed: $DEST/Athanor.saver"
echo "System Settings > Screen Saver > Other > Athanor"
