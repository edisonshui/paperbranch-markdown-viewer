# 34: Restore the Library window at its saved size

**What to build:** Open the Library window at the exact frame it had when Paperbranch quit, instead of growing it at each launch.

**Blocked by:** 17: Restore the Library window size at launch.

**Status:** ready-for-agent

- [ ] Quitting and relaunching keeps the Library window's frame, in both the Variant B and the AppKit presentation.
- [ ] The cause is confirmed and recorded in Comments.
- [ ] Focused test passes red-to-green, then `editor-proof/native-host/verify-package.sh` passes.

## Comments

Found 2026-10-22 in the UX audit. The saved frame was `60 66 1300 883` and the window opened at 1300x935, taller than the screen. Tickets 25 and 26 recorded the same growth: 800 to 852, then 883. Each launch adds 52 points, the height of the title bar plus toolbar (inferred).
