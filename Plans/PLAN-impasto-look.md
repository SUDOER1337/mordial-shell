# PLAN — Impasto "island look" port into Mordial Shell

## Status: Phase 1 (Lock + Session) done; lock is island by default, session opt-in

### Goal
Port the *look* of Impasto (opaque black grounds, white inks, soft shadows,
coarse album wash) into Mordial Shell by restyling Mordial's own components.
No wholesale QML copying, no glass/liquid, no lyrics, no palettes.

### Main look (no toggle)
The lock screen is the island look unconditionally — the original Noctalia
lock UI is removed:

### Settings
- `Commons/Settings.qml` — `islandLook` JsonObject section:
  - `mediaOnLock: true` (album cover wash behind the lock screen)
  - `session: false` (island tiles for the session menu — opt-in)
  - (clock is stacked-only; the brief `lockClockStyle` toggle was removed)
- `settingsVersion` bumped 60 → 61 with a malformed-section guard in
  `migrateRawSettings` (lock was briefly a toggle there; it is now inherent
  and the key disappears from saved files on next write).
- The removed original-look configurators (dead keys stay declared, harmless):
  `general.clockStyle/clockFormat`, `lockScreenBlur/lockScreenTint`,
  `compactLockScreen` (repurposed: slim session buttons/status pill only),
  `enableLockScreenMediaControls`.
- Settings UI (lock Appearance tab): "Media on lock", "Island clock style"
  (inline/stacked), "Random password icons", "Compact lock screen",
  "Lockscreen animations". Session menu keeps its "Island look" opt-in toggle.

### Tokens — `Commons/Look.qml` (new singleton)
`ground #000 / surface #141414 / surfaceHover #1f1f1f / border #262626 /
hairline #20ffffff / ink #fff / inkDim a0.72 / inkMuted a0.55 /
statusBad #ff453a / statusGood #32d74b / scrim #bf000000`.
Text-shadow (0.45/3), wash (scale .1, blur .85/max64, brightness −.28,
saturation .25), lock scrim 0.18, shake (9 / 55ms), motion 140/200/380 ms
divided by `general.animationSpeed`, 0 when animations disabled.

### Lock screen (always island)
- `LockScreen.qml` — info/countdown pills: dark `surface` + hairline + ink
  text; error pill gets `statusBad` border/glyph/label.
- `LockScreenBackground.qml` — black ground only (no wallpaper, no tint, no
  blur) + the album wash when `mediaOnLock && MediaService.trackArtUrl`
  (10 % sourceSize, MultiEffect blur 0.85/64, brightness −0.28, saturation
  0.25) + 0.18 black scrim. Screen corners kept.
- `LockScreenHeader.qml` — display clock only: date line (inkDim, semibold),
  digits 132pt bold with minutes dimmed; `stacked` mode = two lines (96pt,
  negative spacing) with minutes at inkMuted; MultiEffect black shadows.
- `LockScreenPanel.qml` — no bottom card; the morphing auth pill floats on
  the wash and shrinks to wrap it (88px / 154px with session buttons): pill
  60→380 via animated plain property (`islandPillWidth`), avatar-only idle →
  avatar + name + "Enter password" + dots + white submit disc; wrong
  password = red border + shake. Compact status readout recolored
  `Look.surface`. Weather/media info row removed along with its consumers.

### Session menu (gated by `islandLook.session`)
- `SessionMenu.qml` — panel bg `Look.ground`, blur off, opaque card tiles:
  idle `surface` + 1px border, hover/selected `surfaceHover` + 2px
  `Color.mPrimary` border, armed `statusBad` fill with ink glyph and label
  "Confirm"; keybind chips `surfaceHover` + border + ink text; countdown
  pill and Normal-style box recolored. Layout untouched.

### Known residuals / later phases (bar, media, dashboard)
- `LockScreenPanel` keeps pre-existing unqualified `lockContext` refs —
  intentionally untouched.
- Other bar widgets keep MD3 ink on the black band (Phase 2 scope).
- SmartPanel detail expansion instead of the single-window island morph.
- Later phases: `MediaMini`, bar backgrounds, dashboard pages, generic panels.
