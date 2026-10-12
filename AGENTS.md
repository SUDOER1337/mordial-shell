# AGENTS.md — Mordial Shell

**Mordial** is an independent fork of Noctalia Shell v4: a minimal QML-based Wayland desktop shell built with Quickshell.

---

## Project Type & Entry

- **Language**: QML + Qt6
- **Framework**: Quickshell (via `noctalia-qs` fork)
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

### Format & Lint
```bash
./Scripts/dev/qmlfmt.sh       # Format all QML files (uses qmlformat from qt6-declarative)
python3 Scripts/dev/build-settings-search-index.py  # Rebuild settings search index
```

### Pre-commit Hooks
Lefthook runs automatically on `git commit`:
1. **QML formatting** — auto-fixes formatting in all `.qml` files
2. **Settings index** — rebuilds `Assets/settings-search-index.json` from config defaults

To manually test:
```bash
lefthook run pre-commit
```

---

## Project Structure

### `Commons/`
Shared utilities imported as `qs.Commons`:
- **Color.qml** — 30-token MD3 color system consumed by all UI. Tokens are read from `colors.json` via `FileView.watchChanges`, with hardness-tuned fallbacks. Saturation post-processing via `ColorSaturation.apply()`.
- **ColorSaturation.qml** — Per-slot saturation post-processor. Each of 7 semantic slots (primary, secondary, tertiary, error, surface, background, outline) has an independent multiplier read from `Settings.data.colorSchemes.saturation`. Exposes wrapper functions for `ColorsConvert.js` derivation (container color, surface variant, L+S adjust) to avoid cross-namespace JS imports from `qs.Modules.*` files. Includes 3 built-in presets (Vibrant, Muted, Vintage).
- **I18n.qml** — Internationalization strings
- **Settings.qml** — Central settings manager
- **ShellState.qml** — Shell-wide state (loaded, focused monitors, etc.)
- **Style.qml** — Design tokens and spacing
- **Logger.qml** — Debug logging
- **Icons.qml**, **IconsTabler.qml** — Icon sets
- **Keybinds.qml** — Keyboard shortcut binding system
- **Time.qml** — Time and calendar utilities

### `Modules/`
UI components — imported as `qs.Modules.*`:
- **Bar/** — Top/bottom taskbar
- **Dock/** — Application dock
- **LockScreen/** — Lock screen
- **Notification/** — Notification center
- **OSD/** — Volume/brightness overlay
- **Panels/** — Settings, Launcher, and other panels (21+ submodules)
- **DesktopWidgets/** — Floating widgets
- **Toast/** — Toast notifications
- **Background/** — Wallpaper handling
- **MainScreen/** — Primary screen layout

### `Services/`
Backend logic — imported as `qs.Services.*`:
- **Mordial/** — Fork-specific (config, migrations)
- **Theming/** — Color schemes, wallpaper colors, dark mode
- **Control/** — System controls (power, audio, brightness)
- **Networking/** — Network status and WiFi
- **Hardware/** — System info, battery
- **Keyboard/** — Keyboard layout
- **Compositor/** — MangoWC compositor integration (mmsg IPC)
- **UI/** — UI state (focus, monitors, window hints)
- **Power/** — Power management
- **Media/** — Media player controls
- **Location/** — Geolocation

### `Helpers/`
Utility modules (JS, not QML):
- **ColorsConvert.js** — Color space conversions (HSL, RGB, HSV), WCAG contrast utilities, MD3 derivation functions (`generateContainerColor`, `generateSurfaceVariant`, `adjustLightnessAndSaturation`), and `applySaturation` post-processing. Imported by `ColorSaturation.qml` and `ColorSchemeService.qml` via relative path.

### `Scripts/python/src/theming/`
Python pipeline for MD3 color extraction:
- **template-processor.py** — CLI tool that extracts a 48-color MD3 palette from a wallpaper image or expands a predefined scheme. Supports 9 scheme types (`tonal-spot`, `content`, `fruit-salad`, `rainbow`, `monochrome`, `vibrant`, `faithful`, `dysfunctional`, `muted`). Called from QML via `Process` in `TemplateProcessor.qml`.

### `Assets/`
- **settings-default.json** — Factory defaults for all shell settings
- **settings-search-index.json** — Pre-built index for settings search (auto-rebuilt by pre-commit)
- **settings-widgets-default.json** — Default desktop widget configs
- **Launcher/emoji.json** — Emoji data
- All `.json` files are **auto-formatted** by the dev shell

### `Scripts/dev/`
- **qmlfmt.sh** — QML formatter wrapper (parallel, multicore)
- **build-settings-search-index.py** — Regenerate settings search index (run before commit)
- **colorscheme-registry.sh** — Manage color scheme registry
- **i18n-{push,pull}.sh** — Translation sync
- **notifications-test*.sh** — Send test notifications for manual QA
- **shaders-compile.sh** — Compile QML shader effects

---

## Environment Variables

**Development**:
- `MORDIAL_DEBUG=1` — Enable debug logging in shell
- `QS_CONFIG_PATH` — Override config directory (defaults to `~/.config/mordial/`)
- `QT_LOGGING_RULES` — Control Qt debug output (used by qmlformat to suppress noise)

**Build**:
- `QMLFMT_JOBS` — Parallel jobs for `qmlfmt.sh` (defaults to `nproc`)
- `QT_FFMPEG_DECODING_HW_DEVICE_TYPES=vaapi,vdpau` — Hardware video decode
- `QT_FFMPEG_ENCODING_HW_DEVICE_TYPES=vaapi,vdpau` — Hardware video encode

---

## QML Import Namespace

All modules use the `qs.*` import prefix:
```qml
import qs.Commons
import qs.Services.Theming
import qs.Modules.Bar
```

This is managed by Quickshell's module system, not a standard `qmldir`. **Do not rename or reorganize modules** without updating `shell.qml` imports.

---

## Runtime Dependencies

Packaged via Nix, but agents should know these are required for full functionality:
- `brightnessctl` — Brightness control
- `cliphist` — Clipboard history
- `ddcutil` — Monitor DDC control
- `wlsunset` — Automatic color temperature
- `wl-clipboard` — Clipboard access
- `wlr-randr` — Monitor configuration
- `imagemagick` — Image processing (wallpaper colors)
- `wget` — HTTP downloads (wallhaven integration)
- `python3` — Runtime scripts and calendaring (optional: pygobject3)

---

## Important Notes

### Config Migration
- **Old Noctalia**: `~/.config/noctalia/` → **New Mordial**: `~/.config/mordial/`
- Environment variable: `MORDIAL_CONFIG_DIR`, `MORDIAL_CACHE_DIR`
- Color scheme names changed: `"Noctalia (default)"` → `"Mordial (default)"`

### Nix Build Exclusions
These files are excluded from the final package build (see `nix/package.nix`):
- `.github/`, `LICENSE`, `README.md`, `CREDITS.md`
- `flake.nix`, `flake.lock`, `shell.nix`, `lefthook.yml`, `CLAUDE.md`
- `Assets/Screenshots/`, `Scripts/dev/`, `nix/`

Only QML source, configs, and assets are packaged.

### Wayland Compositor Support
Agnoctural targets **MangoWC only**, talking to it via the `mmsg` IPC socket (`MANGO_INSTANCE_SIGNATURE`). `mmsg` must be on PATH. All other compositor backends have been removed.

---

## Testing & Validation

### Shell Load Test
-- Ask user to test it

### Notification Testing
```bash
./Scripts/dev/notifications-test.sh          # Send test notifications
./Scripts/dev/notifications-test-replace.sh  # Test notification replacement
```

## Color Pipeline (MD3)

The shell uses a 30-token Material Design 3 color system derived from either a predefined scheme or a wallpaper image.

### Color Tokens (30 total)
- **16 base tokens**: `mPrimary`, `mOnPrimary`, `mPrimaryContainer`, `mOnPrimaryContainer`, `mSecondary`, `mOnSecondary`, `mSecondaryContainer`, `mOnSecondaryContainer`, `mTertiary`, `mOnTertiary`, `mTertiaryContainer`, `mOnTertiaryContainer`, `mError`, `mOnError`, `mErrorContainer`, `mOnErrorContainer`
- **9 surface tokens**: `mSurface`, `mOnSurface`, `mSurfaceVariant`, `mOnSurfaceVariant`, `mSurfaceContainerLow`, `mSurfaceContainer`, `mSurfaceContainerHigh`, `mBackground`, `mOnBackground`
- **3 outline tokens**: `mOutline`, `mOutlineVariant`, `mShadow`
- **2 hover tokens**: `mHover`, `mOnHover`

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

### Derivation Chain
When a scheme file only has 16 base tokens (missing the 14 derived ones):
1. `generateContainerColor()` — derives `m*Container` from base accent + `mOn*Container` equals base
2. `generateSurfaceVariant()` — derives `mSurfaceContainerLow/Mid/High` from `mSurface` with stepped elevation
3. `adjustLightnessAndSaturation()` — derives `mOutlineVariant` from `mOutline`
4. `mBackground`/`mOnBackground` fall back to `mSurface`/`mOnSurface`

### Saturation Post-Processing
- 7 semantic slots with independent multipliers (stored in `Settings.data.colorSchemes.saturation.*`)
- Applied in `Color.qml` via `ColorSaturation.apply(token, hex)` — each token resolves its slot, multiplier is applied, hex is returned
- 3 built-in presets: Vibrant (1.0 all), Muted (0.5-0.7), Vintage (0.6-0.85)

### Cross-Namespace Import Rule
`ColorsConvert.js` functions (container color, surface variant, blend) must be accessed via `ColorSaturation.*` wrappers when used from `qs.Modules.*` QML files. This is because Quickshell's module system resolves relative paths against the virtual `qs.Modules` namespace, not the actual filesystem. From `qs.Services.*` files, direct relative import (`import "../../Helpers/ColorsConvert.js" as CC`) works.

### QML Lint
```bash
nix develop  # Get access to qmllint (qt6)
qmllint <file.qml>
```

### Format Validation
After changes, always run:
```bash
./Scripts/dev/qmlfmt.sh
python3 Scripts/dev/build-settings-search-index.py
git add -A && lefthook run pre-commit
```

---

## References

- **Upstream (Original Noctalia)**: https://github.com/noctalia-dev/noctalia-shell
- **Quickshell Documentation**: https://quickshell.org/
- **Fork Status**: See `FORK_NOTES.md` for maintenance scope and relationship to Noctalia v5
- **Configuration**: `FORK_NOTES.md` explains config migration from Noctalia v4

---

## Known Constraints

1. **Quickshell Dependency**: Mordial depends on the `noctalia-qs` fork. If unmaintained, shell cannot be updated beyond current Quickshell capabilities.
2. **QML Only**: No C++ rewrites; architecture is QML-based by design.
3. **Wayland Only**: X11 is not supported.
4. **Not a Full DE**: Handles shell UI only—file manager, settings daemon, window manager, greeter are external.
