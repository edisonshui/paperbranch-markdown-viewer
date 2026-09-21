# Paperbranch native host

A small native macOS app (SwiftPM package) that loads the `editor-proof`
harness in a real `WKWebView`. Ticket 02 adds the first complete one-document
workflow: choose a `.md` or `.markdown` file with File > Open, edit formatted
content, and save only through Command-S.

## Structure

- `Sources/PaperbranchBridgeCore/BridgeCoordinator.swift` -- the reusable
  bridge: owns the `WKWebView`, registers the one narrow message handler
  (`"paperbranch"`, carrying only `{ type: "dirtyStateChanged", dirty }`),
  and calls the fixed content-only JS bridge functions.
- `Sources/PaperbranchBridgeCore/DocumentSession.swift` -- native ownership
  of the selected Markdown document, including explicit coordinated writes.
- `Sources/PaperbranchEditorProofHost/` -- the app itself: one window, one
  `WKWebView`, Open and Save commands, dirty window state, errors, and the
  save/discard/cancel close prompt.
- `Tests/PaperbranchBridgeCoreTests/` -- drives a real, off-screen
  `WKWebView`, including a workflow using a real temporary Markdown file.

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

- an edit to a real temporary Markdown file leaves its bytes unchanged until
  `DocumentSession.save()` runs, then writes the serialized result and clears
  dirty state.
- A clean document is replaced by `externalReplace`.
- A dirty document's in-memory content is preserved, byte-for-byte, against
  an `externalReplace` call, and the replacement does not apply.
- An `externalReplace` carrying content the editor-admission seam blocks
  (front matter or math) is correctly blocked rather than loaded, and the
  original source is preserved.
- The only registered `WKScriptMessageHandler` is `"paperbranch"`, and
  `window.paperbranchNativeBridge` exposes only fixed document-content and
  dirty-baseline functions -- nothing resembling file access.

To manually verify the focused-editor path, run `run.sh`, choose a Markdown
document with File > Open, click inside the Document view, edit it, and press
Command-S. `AppDelegate.swift` wires a `Save` `NSMenuItem` with
`keyEquivalent: "s"` and `keyEquivalentModifierMask: [.command]` to the
native `DocumentSession.save()` path.
