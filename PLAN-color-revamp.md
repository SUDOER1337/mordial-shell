# Color System Revamp Plan

## Goals

- **Auto-color from wallpaper** via existing MD3 Python pipeline (keep & refine)
- **7 semantic slots** with per-category saturation sliders (instant QML-side post-process, this shoulds replace every dots color selector to a dropdowns)
- **Deep MD3 variants** per slot (main, on-color, container, on-container)
- **Modular API** consumers bind to (`Color.mPrimary`, `Color.primaryContainer`, etc.)
- **Full backward compatibility** with existing `m*` property names (~1445 usages)

---

## 1. Semantic Slots & Variant Map

| Slot           | Main          | On-Color        | Container                                                                | On-Container            | Children / Notes                   |
| -------------- | ------------- | --------------- | ------------------------------------------------------------------------ | ----------------------- | ---------------------------------- |
| **Primary**    | `mPrimary`    | `mOnPrimary`    | `mPrimaryContainer`                                                      | `mOnPrimaryContainer`   | Accent color, interactive elements |
| **Secondary**  | `mSecondary`  | `mOnSecondary`  | `mSecondaryContainer`                                                    | `mOnSecondaryContainer` | Muted accent                       |
| **Tertiary**   | `mTertiary`   | `mOnTertiary`   | `mTertiaryContainer`                                                     | `mOnTertiaryContainer`  | Playful accent                     |
| **Surface**    | `mSurface`    | `mOnSurface`    | `mSurfaceContainer`<br>`mSurfaceContainerLow`<br>`mSurfaceContainerHigh` | `mOnSurfaceVariant`     | Background panels, cards           |
| **Background** | `mBackground` | `mOnBackground` | `mSurfaceVariant`                                                        | _(shared with Surface)_ | Root background                    |
| **Error**      | `mError`      | `mOnError`      | `mErrorContainer`                                                        | `mOnErrorContainer`     | Destructive / alerts               |
| **Outline**    | `mOutline`    | —               | `mOutlineVariant`                                                        | —                       | Borders, dividers                  |

~30 color tokens total. Backward-compatible aliases preserved for all 14 current names.

---

## 2. Saturation Configuration

Stored in `settings.json` under `colorSchemes.saturation`:

```json
{
  "colorSchemes": {
    "saturation": {
      "primary": 1.0,
      "secondary": 1.0,
      "tertiary": 1.0,
      "surface": 0.9,
      "background": 0.85,
      "error": 1.0,
      "outline": 0.7
    }
  }
}
```

- **Range**: `0.0` (grayscale) to `1.0` (100% of source saturation). Values >1.0 allowed (up to ~1.5) but clamped to valid HSL range.
- **Default**: `1.0` for accents, `0.9`/`0.85` for neutrals (matches MD3 conventions where neutrals are already somewhat desaturated).
- **Storage**: Single flat JSON object, read/written via `Settings.qml`'s existing `JsonAdapter` pattern.

---

## 3. Saturation Processing Layer (QML-side, instant)

### 3.1 New file: `Commons/ColorSaturation.qml` (Singleton)

**Responsibilities:**

- Read saturation config from `Settings.data.colorSchemes.saturation`
- Expose a read-write `property real saturationPrimary` (and friends) for each slot
- Each property emits `onSaturationPrimaryChanged` so Color.qml can re-bind
- Provide `function applySaturationToToken(baseColorHex, slotName) → color`

**Internal logic for `applySaturationToToken`:**

```
1. Receive raw hex + slot name (e.g. "#ffaabb", "primary")
2. Convert hex → HSL via ColorsConvert.hexToHSL()
3. Multiply: hsl.s = clamp(hsl.s * saturationMultiplier, 0, 1)
4. Convert back to hex via ColorsConvert.hslToHex()
5. Return as QML `color` type
```

**Performance notes:**

- Called once per token per saturation change (max ~30 conversions)
- JS conversion is <0.01ms per call — instant for UI
- No Python round-trip, no file I/O

### 3.2 Extend: `Helpers/ColorsConvert.js`

Add:

```js
/** Apply a saturation multiplier to a hex color.
 *  @param hex - 6-char hex string (with or without #)
 *  @param multiplier - 0.0 to ~1.5 (clamped to valid HSL S range)
 *  @returns hex string
 */
export function applySaturation(hex, multiplier) // Apply saturation multiplier
```

---

## 4. `Commons/Color.qml` — Rewrite

### 4.1 Internals

```qml
pragma Singleton
import QtQuick 2.15
import "../Helpers/ColorsConvert.js" as CC

QtObject {
    id: root

    // --- Raw palettes (from wallpaper / predefined schemes) ---
    property var _raw48: ({})          // 48-color expanded palette
    property var _saturation: ({})     // Current saturation multipliers

    // --- Saturation sources (from ColorSaturation singleton) ---
    // Connected via bindings — auto-updates when sliders move

    // --- Exposed color tokens (readonly, reactive) ---
    readonly property color mPrimary: _apply("primary")
    readonly property color mOnPrimary: _apply("onPrimary")
    readonly property color mPrimaryContainer: _apply("primaryContainer")
    readonly property color mOnPrimaryContainer: _apply("onPrimaryContainer")
    // ... all 30 tokens ...

    // --- Internal: resolve + saturate a token ---
    function _apply(token) {
        var raw = _raw48[token];
        if (!raw) return "transparent";
        var slot = _slotOf(token);
        var mult = _saturation[slot] ?? 1.0;
        return CC.applySaturation(raw, mult);
    }

    // --- Token → slot mapping ---
    function _slotOf(token) { /* returns "primary", "surface", etc. */ }

    // --- Public helpers (preserved) ---
    function resolveColorKey(key) { /* ... */ }
    function resolveOnColorKey(key) { /* ... */ }
}
```

### 4.2 Loading Flow

1. **Python pipeline** writes 48 expanded colors to `colors.json`
2. **`FileView` + `JsonAdapter`** reads JSON into `_raw48`
3. **`ColorSaturation`** singleton reads settings → exposes per-slot reals
4. **Bindings** cascade: slider moves → `ColorSaturation.satPrimary` changes → `Color.mPrimary` re-evaluates → all UI bound to `Color.mPrimary` updates

### 4.3 Animation

- Keep existing `Behavior on mPrimary { ColorAnimation { duration: Style.animationSlowest } }`
- Animation fires when the _adjusted_ color changes (whether from raw palette change or slider move)
- Skip on first load via `skipTransition` flag (preserved from current code)

---

## 5. New UI Components

### 5.1 `Widgets/NSaturationSlider.qml`

A slider widget specifically for saturation control:

- Horizontal `Slider` with a gradient track showing the saturation range:
  - Left: fully desaturated version of the slot's main color
  - Right: fully saturated version (1.0× source)
- Label shows current percentage value
- Reset button (circular arrow icon) to restore default
- Emits `onSaturationChanged(real value)`

### 5.2 `Modules/Panels/Settings/Tabs/ColorScheme/SaturationSubTab.qml`

Settings tab with one `NSaturationSlider` per slot:

- 7 sliders, each labeled with the slot name and a small color swatch showing the current adjusted main color
- A "Reset All" button at the top
- Grouped into two sections:
  - **Accents**: Primary, Secondary, Tertiary, Error
  - **Neutrals**: Surface, Background, Outline
- Real-time preview: swatches update as sliders move (no apply button needed)

### 5.3 Update: `ColorSchemeTab.qml`

Add a third sub-tab alongside "Colors" and "Templates":

- Existing: `ColorsSubTab`, `TemplatesSubTab`
- New: `SaturationSubTab`

---

## 6. Sequence Diagram (Data Flow)

```
Wallpaper change
    ↓
Python MD3 pipeline
    ↓
writes 48 colors → colors.json
    ↓
FileView + JsonAdapter (Color.qml)
    ↓
_raw48 populated → all tokens re-evaluated
    ↓
UI updates (animated)

Slider move (by user)
    ↓
ColorSaturation.satPrimary = 0.7
    ↓
Binding triggers Color.mPrimary re-eval
    ↓
CC.applySaturation(rawPrimary, 0.7)
    ↓
UI updates (animated)
```

---

## 7. Implementation Order

| Step | File(s)                                           | Description                                             |
| ---- | ------------------------------------------------- | ------------------------------------------------------- |
| 1    | `Helpers/ColorsConvert.js`                        | Add `applySaturation()` JS function                     |
| 2    | `Commons/ColorSaturation.qml`                     | NEW: saturation config singleton                        |
| 3    | `Commons/Color.qml`                               | Rewrite: 30 tokens, post-process layer, backward compat |
| 4    | `Widgets/NSaturationSlider.qml`                   | NEW: saturation slider widget                           |
| 5    | `Modules/.../SaturationSubTab.qml`                | NEW: settings tab with 7 sliders                        |
| 6    | `Modules/.../ColorSchemeTab.qml`                  | Add Saturation sub-tab                                  |
| 7    | `Assets/settings-default.json`                    | Add default saturation values                           |
| 8    | `Services/Theming/ColorSchemeService.qml`         | Wire saturation into scheme loading                     |
| 9    | Test: `qs -c ~/.config/quickshell/mordial-shell/` | Verify no regressions                                   |

---

## 8. Open Questions / Future

- **Outline slot**: Only has `outline` + `outlineVariant` — no on-color or container. Should we skip it for now and just add the other 6?
- **Saturation range**: Allow >1.0 for "boosted" mode? (Some users like hyper-saturated accents.)
- **48-color expansion**: The Python pipeline already generates 48 colors. Currently only 14 are read by QML. Should we expand to read all 48 in this step, or add that later?
- **Presets**: Should saturation configs be saveable/loadable as presets? (e.g., "Muted", "Vibrant", "Vintage")

---

## 9. Appendix: Property Name Migration

| Old (current)       | New (kept as alias) | Also added                                                           |
| ------------------- | ------------------- | -------------------------------------------------------------------- |
| `mPrimary`          | `mPrimary`          | `mPrimaryContainer`, `mOnPrimaryContainer`                           |
| `mOnPrimary`        | `mOnPrimary`        |                                                                      |
| `mSecondary`        | `mSecondary`        | `mSecondaryContainer`, `mOnSecondaryContainer`                       |
| `mOnSecondary`      | `mOnSecondary`      |                                                                      |
| `mTertiary`         | `mTertiary`         | `mTertiaryContainer`, `mOnTertiaryContainer`                         |
| `mOnTertiary`       | `mOnTertiary`       |                                                                      |
| `mSurface`          | `mSurface`          | `mSurfaceContainerLow`, `mSurfaceContainer`, `mSurfaceContainerHigh` |
| `mOnSurface`        | `mOnSurface`        |                                                                      |
| `mSurfaceVariant`   | `mSurfaceVariant`   |                                                                      |
| `mOnSurfaceVariant` | `mOnSurfaceVariant` |                                                                      |
| `mError`            | `mError`            | `mErrorContainer`, `mOnErrorContainer`                               |
| `mOnError`          | `mOnError`          |                                                                      |
| `mOutline`          | `mOutline`          | `mOutlineVariant`                                                    |
| `mShadow`           | `mShadow`           | Kept as-is                                                           |
| `mHover`            | `mHover`            | Kept as-is                                                           |
| `mOnHover`          | `mOnHover`          | Kept as-is                                                           |
| —                   | `mBackground`       | NEW                                                                  |
| —                   | `mOnBackground`     | NEW                                                                  |
