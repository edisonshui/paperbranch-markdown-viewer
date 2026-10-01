#!/bin/sh
# Builds and launches Paperbranch's offline local app bundle.
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
"$SCRIPT_DIR/package.sh"
open -W "$SCRIPT_DIR/.build/Paperbranch.app"
