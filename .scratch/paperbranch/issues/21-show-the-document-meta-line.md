# 21: Show the document meta line

**What to build:** Show Variant B's meta line above the document with the word count and read time for the selected Markdown document.

**Blocked by:** 13: Complete Variant B reader chrome in the guarded Library presentation.

**Status:** resolved

- [x] The reader shows the word count and read time above the document.
- [x] Both values update after an edit and after an external reload.
- [x] Focused test passes red-to-green, then `editor-proof/native-host/verify-package.sh` passes.

## Comments

Created 2026-09-30 from Ticket 13's visual check. Variant B shows "149 words · 1 min read · Rendered locally". Which items to keep, and whether the count comes from the editor or the native layer, is open.

Resolved 2026-09-30. The open questions were settled with these defaults:

- Items: the meta line shows "N words" and "N min read". Variant B's "Rendered locally" is dropped because the footer already says "Local Markdown". A one-word document reads "1 word".
- Source: the editor counts, not the native layer. `#document-meta` sits in the Document view above `#editor-root` and outside Milkdown, so it never enters the serialized Markdown. `showDocumentStats` counts the words in the editor's rendered text (`doc.textBetween` with space separators), so link targets and Markdown syntax are not counted. Read time is `max(1, ceil(words / 220))`, as in Variant B. It refreshes after every load, every `markdownUpdated` (edits), and `externalReplace` (reloads). A blocked document shows no meta line.
- Because the line is in the web page, it also shows in the AppKit fallback, which is where a dirty document is displayed. That is why it has to update there after an edit.

Verified 2026-09-30:

- Red: `cd editor-proof && npx playwright test tests/constructs/reader-chrome.spec.ts` failed the two meta-line tests on `toHaveText`. They check "4 words" and "1 min read" for a heading plus emphasized and linked text, that the line sits above the first block and stays out of the Markdown, that an edit makes it "5 words", and that a 500-word external replacement makes it "500 words" and "3 min read".
- Red: `testDocumentMetaLineFollowsAnExternalReload`, run against a package built with `harness.ts` and `index.html` stashed, failed with `("Optional("")") is not equal to ("Optional("1 word · 1 min read")")` and the same for "3 words · 1 min read". The test opens a real file through `DocumentSession`, rewrites it on disk, and reads the meta line after the reload.
- Green: both focused runs passed. The full Playwright suite passed 57 of 57.
- `cd editor-proof/native-host && ./verify-package.sh`: Xcode Release build succeeded and all 60 packaged native tests passed.
- `git diff --check`: passed.
- Packaged app, `/private/tmp/pb15-library`: `Reading.md` showed "881 words · 5 min read", which matches `wc -w` on the file without heading markers. `Note.md` showed "2 words". Typing " more words" made it "4 words" in the AppKit fallback. Rewriting the file on disk raised the conflict alert, and Reload Disk showed "6 words". Restoring the original file reloaded the clean document at "2 words". The library matched its backup afterwards. Screenshots, not committed: `/tmp/pb21-open-s.png`, `/tmp/pb21-note-s.png`, `/tmp/pb21-edit-s.png`, `/tmp/pb21-reload-s.png`, `/tmp/pb21-clean-reload-c.png`.

Implementation commit: `6855642`.
