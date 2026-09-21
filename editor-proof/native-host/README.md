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

## What is verified

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

The visible focused-editor path was also verified on 2026-09-21. An
Accessibility-permissioned UI controller focused the loaded Document view,
typed `!`, and sent OS-level Command-S. The host printed
`Command-S requested a save. Received 140 characters of serialized Markdown. No file was written.`

To repeat the check, run `run.sh`, click into the loaded document, and press
Command-S. `AppDelegate.swift` wires a `Save` `NSMenuItem` with
`keyEquivalent: "s"` and `keyEquivalentModifierMask: [.command]` to
the same `BridgeCoordinator.requestSave()` path covered by `test.sh`.
