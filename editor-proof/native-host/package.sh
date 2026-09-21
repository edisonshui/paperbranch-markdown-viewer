#!/bin/sh
# Creates a local, unsigned Paperbranch.app for this Mac.
set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DERIVED_DATA="$SCRIPT_DIR/.build/xcode"

xcodebuild \
  -project "$SCRIPT_DIR/Paperbranch.xcodeproj" \
  -scheme Paperbranch \
  -configuration Release \
  -derivedDataPath "$DERIVED_DATA" \
  CODE_SIGNING_ALLOWED=NO \
  build >&2

APP_PATH="$DERIVED_DATA/Build/Products/Release/Paperbranch.app"
test -d "$APP_PATH"
rm -rf "$SCRIPT_DIR/.build/Paperbranch.app"
cp -R "$APP_PATH" "$SCRIPT_DIR/.build/Paperbranch.app"
printf '%s\n' "$SCRIPT_DIR/.build/Paperbranch.app"
