# Handle external file changes safely

Paperbranch will reload an open Markdown document when another program changes it and the Document view has no unsaved edits. If Paperbranch has unsaved edits, it will keep them and ask the user how to resolve the conflict, which prevents an external change from silently discarding work.
