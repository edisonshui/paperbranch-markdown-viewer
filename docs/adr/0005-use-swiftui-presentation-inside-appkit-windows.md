# Use SwiftUI presentation inside AppKit windows

Paperbranch will keep AppKit responsible for application lifecycle, Library and Standalone windows, Finder events, commands, close handling, and alerts. A shared window-presentation module will use SwiftUI to render Variant B's Library sidebar and window chrome, while each Document view remains the existing WebKit editor.

This narrow hybrid keeps file access, document sessions, and workflow policy in the existing application modules and exposes only semantic presentation state and user actions to SwiftUI. We rejected an AppKit-only presentation because it would preserve the current imperative duplication, and we rejected a full SwiftUI application shell because its identity and window-reconciliation machinery is disproportionate for Paperbranch's first version.
