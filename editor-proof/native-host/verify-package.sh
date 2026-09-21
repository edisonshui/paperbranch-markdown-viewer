#!/bin/sh
# Verifies the offline local app bundle, then runs the packaged-bundle seam.
set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_PATH="$("$SCRIPT_DIR/package.sh")"

plutil -lint "$APP_PATH/Contents/Info.plist"
test -f "$APP_PATH/Contents/Resources/Web/index.html"
! rg -i --files-with-matches 'Folio|prototype switcher|browser file picker' "$APP_PATH/Contents/Resources/Web"

cd "$SCRIPT_DIR"
PAPERBRANCH_PACKAGED_APP_PATH="$APP_PATH" PAPERBRANCH_PROOF_HARNESS_URL="paperbranch-editor://document/index.html" swift test
