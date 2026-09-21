#!/bin/sh
# Starts the same Vite dev server the Playwright suite uses, then runs the
# proof host app pointed at it. Ctrl-C stops both.
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
EDITOR_PROOF_DIR="$(dirname "$SCRIPT_DIR")"

cd "$EDITOR_PROOF_DIR"
npx vite --port 5183 --strictPort >/tmp/paperbranch-proof-vite.log 2>&1 &
VITE_PID=$!
trap 'kill "$VITE_PID" 2>/dev/null || true' EXIT

for _ in $(seq 1 50); do
  if curl -sf http://localhost:5183/ >/dev/null 2>&1; then
    break
  fi
  sleep 0.2
done

cd "$SCRIPT_DIR"
swift run
