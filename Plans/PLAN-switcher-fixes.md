# Plan — Fix Alt-Tab switcher review findings

Scope: act on the code review of commit `34d8b53` (4 warnings + actionable
suggestions). Files touched are all part of the switcher feature.

## Warning 1 — Safety timer auto-commits too early

`Services/UI/WindowSwitcherService.qml:28-33`

The 1.5 s `safetyTimer` restarts on every `next`/`previous`/`open` and fires
`commit()`. It is meant to recover from a *missed* Tab-release bind (e.g. Alt
released before Tab, so the release bind's modifier no longer matches). But 1.5 s
is short enough that a user holding Alt and pausing to read the switcher gets an
unintended commit.

Fix:
- Raise `interval` from `1500` → `5000` (tunable). This keeps it a stuck-state
  recovery net while giving ample time to read/cycle normally.
- Reword the comment to state it is a stuck-state recovery, not a UX timer.
- Drop the unused `property QtObject _safetyTimer:` wrapper; declare the `Timer`
  directly (only the inner `id: safetyTimer` is referenced).

## Warning 2 — Grid overflows the card at ~30+ windows

`Modules/Panels/WindowSwitcher/WindowSwitcherOverlayWindow.qml:45-57, 90-163`

`cardW`/`cardH` are clamped to the screen, but the `GridLayout` keeps its
preferred size and the card has no `clip`, so tiles spill outside the card and
off-screen for large window counts.

Fix:
- Compute `maxCols`/`maxRows` from the overlay's available space.
- Keep the square-ish layout (`ceil(sqrt(n))`) for normal counts; only widen
  columns when the row count would exceed `maxRows`, so the grid always fits.
- Add `clip: true` to the card as a hard guard against any residual overflow.

## Warning 3 — Switcher omits never-focused windows

`Services/Compositor/CompositorService.qml:249-252` (source) +
`Services/UI/WindowSwitcherService.qml:110-145` (consumer)

`CompositorService.windows` skips any toplevel whose `tagId` is `null` (tags for
unfocused windows can't be determined until they gain focus). The switcher
sources from that model, so windows never focused this session are absent.

Fix — source the switcher directly from `ToplevelManager.toplevels`:
- In `buildItems()`, iterate `ToplevelManager.toplevels.values` instead of
  `CompositorService.windows`.
- Rank with the existing `CompositorService.focusHistory` (stores toplevel
  handles, so `indexOf` still works).
- Drop `output`/`workspaceId` from the item snapshot — `commit()` only uses
  `handle` (confirmed: `CompositorService.focusWindow` ignores the other keys
  when `handle` is present).
- Requires `import Quickshell.Wayland` in the service (already imported there
  for other use? verify; add if missing).
- `focusedScreen()` is unchanged (still uses `getFocusedWindow()`).

Trade-off: the switcher no longer inherits the tag/workspace filtering, which is
exactly the point — Alt-Tab should list all windows.

## Warning 4 — Clicking card padding cancels the switcher

`Modules/Panels/WindowSwitcher/WindowSwitcherOverlayWindow.qml:76-185`

`NBox` has no `MouseArea`, so clicks on the card's padding/header fall through to
the dimmer's `onClicked: cancel()` (dimmer is a lower sibling; the event reaches
it).

Fix: add an empty `MouseArea` filling the card that consumes clicks (no-op
handler) so they stop at the card and never reach the dimmer.

## Suggestions (batched)

- `WindowSwitcherService.qml:86-90` — `commit()` passes unused
  `workspaceId`/`output`; simplify to focus by handle only (aligns with Warning 3).
- `CompositorService.qml:286-288` — collapse the two-pass
  `some()`+`filter()` history cleanup into a single `filter()`.
- Both switcher files — add the file-level function index and `@param`/`@returns`
  required by `AGENTS.md` (missing on `open(direction)` and both file headers).

Dropped: the "double icon resolution" suggestion — `findAppEntry` (appId→entry)
and `iconFromName` (name→path) are complementary steps, not redundant.

## Verification

- `./Scripts/dev/qmlfmt.sh` then `lefthook run pre-commit` (auto-rebuilds the
  settings index).
- Manual QA (ask user): hold Alt + tap Tab repeatedly, pause >1.5 s then release
  (should NOT auto-commit); open with 30+ windows (grid fits, no spill); Alt-Tab
  to a window on another workspace never focused this session (should appear);
  click the card padding (should not cancel).
