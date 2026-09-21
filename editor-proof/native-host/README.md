# Native editor proof host

A minimal macOS app (SwiftPM package, not an Xcode project -- lighter
weight for a throwaway proof host) that loads the `editor-proof` harness in
a real `WKWebView` and exercises the native/editor bridge described in
`docs/specs/paperbranch-implementation.md` ("Native and editor boundary")
and Ticket 01. It does not do file I/O, Library browsing, or persistence --
none of that is in scope here.

## Structure

- `Sources/PaperbranchBridgeCore/BridgeCoordinator.swift` -- the reusable
  bridge: owns the `WKWebView`, registers the one narrow message handler
  (`"paperbranch"`, carrying only `{ type: "dirtyStateChanged", dirty }`),
  and exposes `requestSave()` and `externalReplace(markdown:)`, which call
  the two functions the JS side exposes at
  `window.paperbranchNativeBridge`. This is a library target so both the
  app and the test target share it.
- `Sources/PaperbranchEditorProofHost/` -- the app itself: one window, one
  `WKWebView`, deterministic sample Markdown loaded after navigation, and a
  Save menu item bound to Command-S.
- `Tests/PaperbranchBridgeCoreTests/` -- drives a real, off-screen
  `WKWebView` through `BridgeCoordinator` to verify the bridge without a
  human at the keyboard (see "What is and isn't verified" below).

## Running

Both `run.sh` and `test.sh` start the same Vite dev server the Playwright
suite in `editor-proof/` uses (`localhost:5183`), point the native host or
tests at it, and shut the server down on exit.

```sh
# The app, with a visible window:
native-host/run.sh

# The automated bridge tests:
native-host/test.sh
```

`PAPERBRANCH_PROOF_HARNESS_URL` overrides the harness URL if something else
is already using port 5183.

## What is and isn't verified

The `test.sh` suite programmatically verifies, against a real `WKWebView`
(not a mock):

- `requestSave()` returns the live serialized Markdown and touches nothing
  on disk (checked by snapshotting the `editor-proof` directory before and
  after).
- A clean document is replaced by `externalReplace`.
- A dirty document's in-memory content is preserved, byte-for-byte, against
  an `externalReplace` call, and the replacement does not apply.
- An `externalReplace` carrying content the editor-admission seam blocks
  (front matter or math) is correctly blocked rather than loaded, and the
  original source is preserved.
- The only registered `WKScriptMessageHandler` is `"paperbranch"`, and
  `window.paperbranchNativeBridge` exposes exactly `requestSave` and
  `externalReplace` -- nothing resembling file access.

What this does **not** verify, and would need a human (or
Accessibility-permissioned UI scripting, which itself needs a human to
grant the permission once): the literal OS-level delivery of a physical
Command-S keystroke into a visible, focused window. `AppDelegate.swift`
wires a `Save` `NSMenuItem` with `keyEquivalent: "s"` and
`keyEquivalentModifierMask: [.command]`, targeting `handleSave()`, which
calls the same `BridgeCoordinator.requestSave()` the tests exercise
directly. AppKit resolves a Command-key event against the main menu's key
equivalents before it reaches a view's own `keyDown` handling, which is why
this reaches the native host even with the `WKWebView` focused -- but that
resolution is standard OS behavior this proof relies on rather than
re-verifies; what's proof-specific (the menu item exists with the right key
equivalent and calls the save path with no file write) is what the test
suite covers. Manually confirming the physical keystroke means: run
`run.sh`, click into the loaded document, and press Command-S -- the
console should print a line like `Command-S requested a save. Received N
characters of serialized Markdown. No file was written.`

An attempt to verify this via `osascript`/System Events UI scripting was
tried and abandoned: it hangs waiting on an Accessibility permission
prompt, which is exactly the human-in-the-loop step this was trying to
avoid, not a way around it.
