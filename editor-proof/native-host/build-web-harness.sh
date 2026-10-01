#!/bin/sh
# Called by Xcode's Paperbranch target to put the formatted editor in the app.
set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
EDITOR_PROOF_DIR="$(dirname "$SCRIPT_DIR")"
DESTINATION="$1"

cd "$EDITOR_PROOF_DIR"
npx vite build --base ./ --outDir "$DESTINATION" --emptyOutDir
