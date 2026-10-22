# Paperbranch screens

Each screen's layout and its one hard rule. Parts named here are in [components.md](components.md). The guideline's mockup page for each screen is in brackets.

## Library window, reading

[Guideline page 10]

Layout, left to right: the Library sidebar (260 px: wordmark, "Open now" card, "Library" tree), then the main area. The main area stacks the top bar (52 px), the 2 px reading progress line, and the Document view. The Document view centers a 680 px text column: meta line, title, body, footer. The outline panel (220 px) sits on the right when the window is 1240 px or wider. Below that width, the outline renders under the Library tree. The default window is 1300 by 800 px.

**Hard rule:** switching documents changes only the Document view's content, the selected row, the Open now card, and the top bar title. The sidebar, the top bar, and the column stay where they are.

## Library window, editing

[Guideline page 11]

Same layout as reading. A non-empty text selection shows the formatting popover above it. The top bar title gains "· Edited", and the Open now card gains a dot and "Edited".

**Hard rule:** the first keystroke changes only those two status marks. The window keeps its presentation.

## No document selected

The Library is chosen but no document is selected. The Document view shows one centered line in `--text-ui` `--ink-muted`: "Choose a document from the Library". The top bar shows no title.

**Hard rule:** the sidebar looks the same as when a document is selected, minus the Open now card.

## Choosing a Library

[Guideline page 12]

First launch, before any Library exists. The sidebar shows the wordmark only. The main area shows a state view: `folder` icon, "Choose a Library", "Pick a folder of Markdown documents. Paperbranch shows its folders in the sidebar and opens it again next time.", a secondary "Open a Document…", and a primary "Choose Library…".

**Hard rule:** it appears inside the real Library window, so first launch looks like the app.

## Library unavailable

[Guideline page 13]

The sidebar shows the wordmark, the "Library" label, and one `--ink-muted` caption: "<Library name> is unavailable." The main area shows a state view: `folder.badge.questionmark` icon, "Library unavailable", "Paperbranch can't reach <Library name>. The folder may have moved, or its drive may be disconnected.", a secondary "Choose Another Library…", and a primary "Reconnect".

**Hard rule:** the window frame stays, and there is exactly one way back per button.

## Document unavailable

A Library document moved or was deleted while selected. The Library tree stays visible and usable. The Document view shows a state view: `doc.text` icon, "Document unavailable", "<Document name> may have been moved or deleted. Choose another document from the Library." It has no buttons, because the tree is the way back. This was a judgment call on 22 Oct 2026, because the guideline names the state but not its actions.

**Hard rule:** unrelated work stays untouched. Other windows and the tree keep working.

## Conflict alert

[Guideline page 14]

A native `NSAlert` sheet on the window, raised when a document with unsaved edits changes on disk. The top bar title shows "· Changed on disk" in `--danger` behind it.

- Title: "Changes conflict in <document name>"
- Message: "This document changed on disk while you have unsaved edits. Keep your edits, or reload the version on disk and lose them."
- Buttons: "Keep My Edits" (default), then "Reload from Disk" with `hasDestructiveAction`.

**Hard rule:** Return keeps the edits. Nothing is lost by pressing the default button.

## Overwrite warning

A native `NSAlert` sheet raised by the first save after the user chose Keep My Edits on a conflict (spec user story 28, which Edison confirmed on 22 Oct 2026).

- Title: "Overwrite newer disk version of <document name>?"
- Message: "Paperbranch will replace the version changed outside the app with your in-memory edits."
- Buttons: "Cancel" (default), then "Overwrite" with `hasDestructiveAction`. This was a judgment call on 22 Oct 2026: Apple's guidance keeps a destructive button off the default, so Return writes nothing.

**Hard rule:** Cancel writes nothing and leaves the document marked Edited.

## Unsaved edits on switch or close

A native `NSAlert` sheet when the user selects another Library document, or closes a window, while the current document has unsaved edits (Ticket 35).

- Title: "Save changes to <document name>?"
- Message: "Your edits will be lost if you do not save them."
- Buttons: "Save" (default), "Cancel", then "Discard" with `hasDestructiveAction`.

**Hard rule:** Cancel keeps the current document selected, and the sidebar selection snaps back to it.

## Sidebar collapsed

[Guideline page 15]

The Library sidebar slides out in 200 ms. The sidebar toggle moves beside the window buttons in the top bar. The Document view keeps the centered 680 px column, and the outline panel keeps its rule of 1240 px and wider.

**Hard rule:** the column moves with the sidebar in one 200 ms slide, and the reading position stays on the same line.

## Standalone window

[Guideline page 16]

One Standalone document, no Library. The top bar holds the window buttons and the document name with its status, with no sidebar toggle and no Open button. Below it come the progress line and the Document view, with the outline panel at 1240 px and wider.

**Hard rule:** a Standalone window shows no Library parts: no sidebar, no Open now card, no Library label.
