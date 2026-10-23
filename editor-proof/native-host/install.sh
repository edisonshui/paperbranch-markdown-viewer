#!/bin/sh
# Builds Paperbranch, installs it in /Applications, and makes it the app that
# opens .md and .markdown files. Run it again after a change to update the app.
set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TARGET="/Applications/Paperbranch.app"
LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"

if pgrep -xq Paperbranch; then
  echo "Paperbranch is running. Quit it first so unsaved edits are not lost." >&2
  exit 1
fi

BUILT="$("$SCRIPT_DIR/package.sh")"
rm -rf "$TARGET"
ditto "$BUILT" "$TARGET"

# Only the installed copy should answer Finder, so forget the two build copies.
"$LSREGISTER" -u "$BUILT" 2>/dev/null || true
"$LSREGISTER" -u "$SCRIPT_DIR/.build/xcode/Build/Products/Release/Paperbranch.app" 2>/dev/null || true
"$LSREGISTER" -f "$TARGET"

swift - "$TARGET" <<'SWIFT'
import AppKit
import UniformTypeIdentifiers
let app = URL(fileURLWithPath: CommandLine.arguments[1])
let done = DispatchSemaphore(value: 0)
NSWorkspace.shared.setDefaultApplication(at: app, toOpen: UTType("net.daringfireball.markdown")!) { error in
    if let error { fatalError("Could not set the default app for Markdown: \(error)") }
    done.signal()
}
done.wait()
SWIFT

echo "Installed $TARGET and set it to open Markdown documents."
