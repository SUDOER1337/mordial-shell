# AGENTS.md — Mordial Shell

**Mordial** is an independent fork of Noctalia Shell v4: a minimal QML-based Wayland desktop shell built with Quickshell.

---

## Project Type & Entry

- **Language**: QML + Qt6
- **Framework**: Quickshell (upstream, patched in `nix/quickshell-patched.nix`)
- **Main entry**: `shell.qml` (ShellRoot component)
- **Package manager**: Nix flakes
- **Config path**: `~/.config/mordial/` (not `~/.config/noctalia/`)

---

## Build & Test Commands

### Dev Environment

```bash
nix develop            # Enter dev shell with quickshell, qt6, and all tools
nix flake show         # Show available derivations
```

### Build

```bash
nix build              # Build the shell package
```

### Dev Loop (no rebuild for QML edits)

Quickshell hot-reloads QML on save (the `Connections` block on `Quickshell` in `shell.qml` handles `onReloadCompleted`/`onReloadFailed`), so `nix build` is **not** part of the normal edit loop.

The clone at `~/.config/quickshell/mordial-shell` is the live working tree. The system-installed copy lives in the Nix store (`nix/package.nix`) and is launched via the `mordial-shell` wrapper. To test edits against the installed wrapper (patched quickshell + pinned mesa + runtime deps), override its `QS_CONFIG_PATH` (the wrapper sets it with `--set-default`, so an exported value wins):

```bash
QS_CONFIG_PATH=~/.config/quickshell/mordial-shell mordial-shell   # restarts a dev instance pointed at the live tree
qs -c mordial-shell                                                # devshell alternative (see EGL note below)
```

The devshell runs `qs` unwrapped, so `nix/shell.nix` exports `__EGL_VENDOR_LIBRARY_FILENAMES` pointing at the flake's own mesa — otherwise libglvnd loads the host's `/run/opengl-driver` mesa (built against a newer glibc than the shell's runtime) and the shell renders nothing. Caveat: the devshell does **not** add the runtime deps (`wlr-randr`, `imagemagick`, …) to `PATH` the way the wrapper does; install them system-wide or use the wrapper for full functionality.

Only run `nix build` when you changed something under `nix/`, or want the system-wide install updated. The latter comes from the `github:SUDOER1337/mordial-shell` flake input in `~/nixos-config/flake.nix`, so it requires commit → push → `nix flake update mordial-shell` → rebuild.

### Format & Lint

```bash
./Scripts/dev/qmlfmt.sh       # Format all QML files (uses qmlformat from qt6-declarative)
python3 Scripts/dev/build-settings-search-index.py  # Rebuild settings search index
```

After changes, always run the formatter and the pre-commit hooks (which also re-stage formatted files and the regenerated index):

```bash
./Scripts/dev/qmlfmt.sh
python3 Scripts/dev/build-settings-search-index.py
git add -A && lefthook run pre-commit
```

QML lint (needs devshell for `qmllint`):

```bash
nix develop -c qmllint <file.qml>
```

### Pre-commit Hooks

Lefthook runs automatically on `git commit`:

1. **QML formatting** — auto-fixes formatting in all `.qml` files
2. **Settings index** — rebuilds `Assets/settings-search-index.json` from config defaults

---

## Project Structure

### `Commons/`

Shared utilities imported as `qs.Commons`:

- **Color.qml** — 30-token MD3 color system consumed by all UI. Tokens are read from `colors.json` via `FileView.watchChanges`, with hardness-tuned fallbacks. Saturation post-processing via `ColorSaturation.apply()`.
- **ColorSaturation.qml** — Per-slot saturation post-processor. Each of 7 semantic slots (primary, secondary, tertiary, error, surface, background, outline) has an independent multiplier read from `Settings.data.colorSchemes.saturation`. Exposes wrapper functions for `ColorsConvert.js` derivation (container color, surface variant, L+S adjust) to avoid cross-namespace JS imports from `qs.Modules.*` files. Includes 3 built-in presets (Vibrant, Muted, Vintage).
- **Settings.qml** — Central settings manager; also owns the schema migration system (see below)
- **I18n.qml**, **ShellState.qml**, **Style.qml**, **Logger.qml**, **Time.qml**, **Keybinds.qml**, **FuzzySort.qml**, **ThemeIcons.qml**, **Icons.qml**, **IconsTabler.qml**

### `Widgets/`

Reusable `N*`-prefixed UI components (`NButton`, `NLabel`, `NToggle`, `NComboBox`, …) imported as `qs.Widgets`. Used across panels, settings, and bar widgets — **use these instead of raw QtQuick Controls** when building UI. See `Docs/adding-a-bar-widget.md` for usage.

### `Modules/`

UI components — imported as `qs.Modules.*`:

- **Bar/** — Top/bottom taskbar (widgets live in `Bar/Widgets/`, registry in `Services/UI/BarWidgetRegistry.qml`)
- **Dock/** — Application dock
- **LockScreen/** — Lock screen
- **Notification/** — Notification center
- **OSD/** — Volume/brightness overlay
- **Panels/** — Settings, Launcher, WindowSwitcher, and other panels
- **DesktopWidgets/** — Floating widgets
- **Cards/** — Dashboard cards (calendar, notification, weather)
- **Toast/** — Toast notifications
- **Tooltip/** — Tooltip overlay
- **Background/** — Wallpaper handling
- **MainScreen/** — Primary screen layout

### `Services/`

Backend logic — imported as `qs.Services.*`:

- **Mordial/** — Fork-specific (config, migrations)
- **Theming/** — Color schemes, wallpaper colors, dark mode
- **Control/** — System controls (power, audio, brightness) and IPC handlers (`IPCService.qml`, `CustomButtonIPCService.qml`, `PomodoroIPCService.qml`)
- **Networking/** — Network status and WiFi
- **Hardware/** — System info, battery
- **System/** — Fonts, host info, notifications, sound, system stats
- **Keyboard/** — Keyboard layout
- **Compositor/** — MangoWC compositor integration (mmsg IPC)
- **UI/** — UI state (focus, monitors, window hints, bar widget registry)
- **Power/** — Power management
- **Media/** — Media player controls
- **Location/** — Geolocation

### `Helpers/`

Utility modules (JS, not QML): `ColorsConvert.js` (color space conversions, WCAG contrast, MD3 derivation, saturation), plus `sha256.js`, `Debug.js`, and others. `ColorsConvert.js` is imported by `ColorSaturation.qml` and `ColorSchemeService.qml` via relative path.

### `Scripts/python/src/theming/`

- **template-processor.py** — Extracts a 48-color MD3 palette from a wallpaper image or expands a predefined scheme (9 scheme types). Called from QML via `Process` in `Services/Theming/TemplateProcessor.qml`.

### `Assets/`

- **settings-default.json** — Factory defaults for all shell settings
- **settings-search-index.json** — Pre-built index for settings search (auto-rebuilt by pre-commit)
- **settings-widgets-default.json** — Default desktop widget configs
- **Launcher/emoji.json** — Emoji data

### `Scripts/dev/`

`qmlfmt.sh` (parallel formatter), `build-settings-search-index.py`, `colorscheme-registry.sh`, `i18n-{push,pull}.sh`, `notifications-test*.sh` (manual QA), `shaders-compile.sh`. Excluded from the packaged build.

### `Plans/`

Active planning docs (`TODO.md`, `PLAN-*.md`) — check here for in-flight work before starting anything large.

---

## Environment Variables

- `MORDIAL_DEBUG=1` — Enable debug logging (`Settings.isDebug`)
- `QS_CONFIG_PATH` — Override config directory (defaults to `~/.config/mordial/`)
- `MORDIAL_CONFIG_DIR` / `MORDIAL_CACHE_DIR` — Override config/cache directories
- `QMLFMT_JOBS` — Parallel jobs for `qmlfmt.sh` (defaults to `nproc`)
- `QT_LOGGING_RULES` — Control Qt debug output (used by qmlfmt to suppress noise)

---

## QML Import Namespace

All modules use the `qs.*` import prefix:

```qml
import qs.Commons
import qs.Widgets
import qs.Services.Theming
import qs.Modules.Bar
```

This is managed by Quickshell's module system, not a standard `qmldir`. **Do not rename or reorganize modules** without updating `shell.qml` imports.

---

## Settings Schema Migrations

`Commons/Settings.qml` owns a versioned migration system:

- `settingsVersion` (currently 60) is bumped when the settings schema changes
- `migrateRawSettings(raw)` applies one-shot idempotent key renames on the raw JSON **before** it reaches the typed adapter — the adapter silently drops keys it no longer declares, so renamed sections must be copied across by hand

**When changing the settings schema**: bump `settingsVersion`, add a gated migration step to `migrateRawSettings()` (check for the old key's presence so it's safe to re-run), and update `Assets/settings-default.json`. The pre-commit hook regenerates the search index automatically.

---

## Runtime Dependencies

Packaged via Nix (see `runtimeDeps` in `nix/package.nix`): `brightnessctl`, `cliphist`, `ddcutil`, `wlsunset`, `wl-clipboard`, `wlr-randr`, `imagemagick`, `wget`, `python3` (optional `pygobject3` for calendar). Agents should know these are required for full functionality — "command not found" at runtime usually means a missing dep, not a code bug.

---

## Important Notes

### Config Migration

- **Old Noctalia**: `~/.config/noctalia/` → **New Mordial**: `~/.config/mordial/`
- Color scheme names changed: `"Noctalia (default)"` → `"Mordial (default)"` (also an older intermediate rebrand, `"Agnoctural"`, is migrated in `migrateRawSettings`)

### Nix Build Exclusions

Excluded from the final package (see `lib.cleanSourceWith` in `nix/package.nix`): `LICENSE`, `README.md`, `CREDITS.md`, `flake.nix`, `flake.lock`, `shell.nix`, `lefthook.yml`, `CLAUDE.md`, `.gitignore`, `Assets/Screenshots/`, `Scripts/dev/`, `nix/`. Only QML source, configs, and assets are packaged.

### Wayland Compositor Support

Mordial targets **MangoWC only**, talking to it via the `mmsg` IPC socket (`MANGO_INSTANCE_SIGNATURE`). `mmsg` must be on PATH. All other compositor backends have been removed.

### IPC Commands

- Every `IpcHandler` is exposed as `qs ipc call <target> <function> [args...]`. List at runtime with `qs ipc show`.
- Handlers live in `Services/Control/IPCService.qml` (standard targets), `Services/Control/CustomButtonIPCService.qml` (`cb`), and `Services/Control/PomodoroIPCService.qml` (`pomodoro`).
- **`Docs/IPC.md` is the source of truth for the command list — keep it in sync.** When you add, remove, rename, or change the arguments of an `IpcHandler` function, update the matching table in `Docs/IPC.md`.

---

## Testing & Validation

There is **no automated test suite**. Validation is manual:

- **Shell load test**: ask the user to test it after significant changes
- **Notification testing**: `./Scripts/dev/notifications-test.sh` and `./Scripts/dev/notifications-test-replace.sh`

---

## Color Pipeline (MD3)

The shell uses a 30-token Material Design 3 color system derived from either a predefined scheme or a wallpaper image.

### Data Flow

```
Wallpaper Image or Predefined Scheme JSON
    ↓
TemplateProcessor.qml (Python Process) → template-processor.py
    ↓
ColorSchemeService.qml → writeColorsToDisk() → colors.json
    ↓
Color.qml (FileView.watchChanges detects change)
    ↓  (saturation post-processing via ColorSaturation.apply())
UI components bound to Color.* properties
```

### Token Groups

- **16 base**: `mPrimary`/`mOnPrimary`/`mPrimaryContainer`/`mOnPrimaryContainer` + same pattern for `mSecondary`, `mTertiary`, `mError`
- **9 surface**: `mSurface`, `mOnSurface`, `mSurfaceVariant`, `mOnSurfaceVariant`, `mSurfaceContainerLow`, `mSurfaceContainer`, `mSurfaceContainerHigh`, `mBackground`, `mOnBackground`
- **3 outline**: `mOutline`, `mOutlineVariant`, `mShadow`
- **2 hover**: `mHover`, `mOnHover`

### Derivation Chain

When a scheme file only has 16 base tokens (missing the 14 derived ones):

1. `generateContainerColor()` — derives `m*Container` from base accent + `mOn*Container` equals base
2. `generateSurfaceVariant()` — derives `mSurfaceContainerLow/Mid/High` from `mSurface` with stepped elevation (the "mid" level is the token `mSurfaceContainer`)
3. `adjustLightnessAndSaturation()` — derives `mOutlineVariant` from `mOutline`
4. `mBackground`/`mOnBackground` fall back to `mSurface`/`mOnSurface`

### Saturation Post-Processing

- 7 semantic slots with independent multipliers (stored in `Settings.data.colorSchemes.saturation.*`)
- Applied in `Color.qml` via `ColorSaturation.apply(token, hex)` — each token resolves its slot, multiplier is applied, hex is returned
- 3 built-in presets: Vibrant (1.0 all), Muted (0.5-0.7), Vintage (0.6-0.85)

### Cross-Namespace Import Rule

`ColorsConvert.js` functions (container color, surface variant, blend) must be accessed via `ColorSaturation.*` wrappers when used from `qs.Modules.*` QML files. This is because Quickshell's module system resolves relative paths against the virtual `qs.Modules` namespace, not the actual filesystem. From `qs.Services.*` files, direct relative import (`import "../../Helpers/ColorsConvert.js" as CC`) works.

---

## References

- **Upstream (Original Noctalia)**: https://github.com/noctalia-dev/noctalia-shell
- **Quickshell Documentation**: https://quickshell.org/
- **Contributor Docs**: `Docs/` — see `Docs/bar-widgets.md` / `Docs/desktop-widgets.md` (how widgets work) and `Docs/adding-a-bar-widget.md` / `Docs/adding-a-desktop-widget.md` (how to add one)
- **Fork Status**: See `CREDITS.md` for maintenance scope and relationship to Noctalia v5

---

## Known Constraints

1. **Quickshell Patching**: Mordial runs on upstream Quickshell with three features re-applied as patches in `nix/patches/quickshell/` (audio spectrum, Region `CornerState`, `flushWaylandState`). Upstream bumps may require rebasing these patches.
2. **QML Only**: No C++ rewrites; architecture is QML-based by design.
3. **Wayland Only**: X11 is not supported.
4. **Not a Full DE**: Handles shell UI only—file manager, settings daemon, window manager, greeter are external.

---

## Keyboard Navigation (Vim-style)

Mordial uses a keyboard-first interaction model. See `Plans/VIM.md` for details on:

- **Modes**: Normal Mode (navigation) and Insert Mode (text entry)
- **Focus/Selection**: Independent concepts for input regions and highlighted items
- **Keybindings**: `j/k` navigate vertically, `h/l` navigate horizontally (tabs), `i/a` enter Insert Mode, `Enter` activate, `Esc` cancel/close
- **Shared Principles**: Consistent navigation across launcher, powermenu, notification center, session menu

Components should implement this as a reusable interaction system, not duplicate key handling.
