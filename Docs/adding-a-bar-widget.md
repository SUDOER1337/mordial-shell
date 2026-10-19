# Adding a Bar Widget — Step-by-Step

Companion to [`bar-widgets.md`](bar-widgets.md), which explains the machinery.
This is the checklist for shipping a new widget.

We'll build a hypothetical widget called **`Foo`**.

---

## TL;DR

1. Create `Modules/Bar/Widgets/Foo.qml` with the standard property contract.
2. Register it in `Services/UI/BarWidgetRegistry.qml` (`widgets` map +
   `Component` property, plus `widgetMetadata` / `widgetSettingsMap` if it has
   settings).
3. _(Optional)_ add `Modules/Panels/Settings/Bar/WidgetSettings/FooSettings.qml`.
4. _(Optional)_ add `{ "id": "Foo" }` to a zone in
   `Assets/settings-default.json` → `bar.widgets`.
5. Run the formatter and the settings-index builder.

No `qmldir`, no import manifest, no loader registration — the ID + file name
pair is the whole contract.

---

## Step 1 — Create the widget file

**Path: `Modules/Bar/Widgets/Foo.qml`** (name **must** equal the widget ID).

### Required property contract

```qml
property ShellScreen screen
property string widgetId: ""
property string section: ""
property int sectionWidgetIndex: -1
property int sectionWidgetsCount: 0
```

These are injected as initial properties by `BarWidgetLoader._initialProps()`
(`Modules/Bar/Extras/BarWidgetLoader.qml:61-69`), so they must exist before
`Component.onCompleted`.

### Choose a visual base

| Style                 | Root                        | Use for                     | Example                              |
| --------------------- | --------------------------- | --------------------------- | ------------------------------------ |
| Square icon button    | `NIconButton`               | simple toggles              | `Modules/Bar/Widgets/NightLight.qml` |
| Icon + expanding text | `Item` wrapping a `BarPill` | status/controls with labels | `Modules/Bar/Widgets/Volume.qml`     |
| Fully custom          | `Item` + own layout         | complex widgets             | `Modules/Bar/Widgets/Clock.qml`      |

---

### Full template (NIconButton style)

Copy-paste starting point — a self-contained toggle widget with settings
resolution and a right-click settings entry:

```qml
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Modules.Bar.Extras
import qs.Services.UI
import qs.Widgets

NIconButton {
  id: root

  property ShellScreen screen

  // Widget properties passed from Bar.qml for per-instance settings
  property string widgetId: ""
  property string section: ""
  property int sectionWidgetIndex: -1
  property int sectionWidgetsCount: 0

  property var widgetMetadata: BarWidgetRegistry.widgetMetadata[widgetId] ?? {}
  readonly property string screenName: screen ? screen.name : ""
  property var widgetSettings: {
    if (section && sectionWidgetIndex >= 0 && screenName) {
      var widgets = Settings.getBarWidgetsForScreen(screenName)[section];
      if (widgets && sectionWidgetIndex < widgets.length) {
        return widgets[sectionWidgetIndex];
      }
    }
    return {};
  }

  // Resolve each setting: user value wins, else registry default
  readonly property string iconColorKey: widgetSettings.iconColor !== undefined ? widgetSettings.iconColor : widgetMetadata.iconColor

  baseSize: Style.getCapsuleHeightForScreen(screen?.name)
  applyUiScale: false
  customRadius: Style.radiusL

  colorBg: Settings.data.someFeature.enabled ? Color.mPrimary : Style.capsuleColor
  colorFg: Settings.data.someFeature.enabled ? Color.mOnPrimary : Color.resolveColorKey(iconColorKey)
  border.color: Style.capsuleBorderColor
  border.width: Style.capsuleBorderWidth

  icon: Settings.data.someFeature.enabled ? "check" : "x"
  tooltipText: "Foo"
  tooltipDirection: BarService.getTooltipDirection(screen?.name)

  onClicked: {
    Settings.data.someFeature.enabled = !Settings.data.someFeature.enabled;
  }

  NPopupContextMenu {
    id: contextMenu

    model: [
      { "label": "Widget settings", "action": "widget-settings", "icon": "settings" }
    ]

    onTriggered: action => {
                   contextMenu.close();
                   PanelService.closeContextMenu(screen);
                   if (action === "widget-settings") {
                     BarService.openWidgetSettings(screen, section, sectionWidgetIndex, widgetId, widgetSettings);
                   }
                 }
  }

  onRightClicked: PanelService.showContextMenu(contextMenu, root, screen);
}
```

### Rules the template obeys

- **Sizing**: `implicitWidth`/`implicitHeight` come from the base component.
  `BarWidgetLoader` sets the **cross-axis** to fill the bar for extended click
  areas (`BarWidgetLoader.qml:114-125`) — don't hard-code a full bar height.
- **Hiding**: if your root ends up at `opacity: 0`, layout space is collapsed
  (`BarWidgetLoader.qml:42-43`). To occupy space while invisible, expose
  `hideMode: "transparent"`.
- **Colors**: use `Color.resolveColorKey(...)` for any setting whose default
  is `"none"`.
- **Orientation**: if your layout differs for horizontal vs vertical bars, read
  `Settings.getBarPositionForScreen(screenName)` and compare against
  `"left" | "right"` (see `Modules/Bar/Widgets/Clock.qml:35-36`).
- **Hot corner**: if your widget should respond to the bar's edge hot corners,
  expose a `clicked()` function (`Modules/Bar/Bar.qml:33-59` skips widgets
  without one, and skips `Spacer`).
- **Expensive work**: heavy polling/animation should be considered carefully —
  flag-worthy widgets go in `cpuIntensiveWidgets`
  (`BarWidgetRegistry.qml:467`).

---

## Step 2 — Register it

**File: `Services/UI/BarWidgetRegistry.qml`**

Four places, only the first two are mandatory:

### 2a. `widgets` map — **required** (`:12-43`)

```qml
property var widgets: ({
  ...
  "Foo": fooComponent
})
```

Without this, `BarWidgetRegistry.hasWidget("Foo")` is false and the widget is:

- never loaded by `BarWidgetLoader` (`BarWidgetLoader.qml:74-76`),
- filtered out of the bar models (`Modules/Bar/Bar.qml:24-31`),
- **deleted from user settings** on next load (`Commons/Settings.qml:1296`),
- missing from the "add widget" list (`BarTab.qml:130`).

### 2b. Component property — **required** (`:352-441`)

```qml
property Component fooComponent: Component {
  Foo {}
}
```

The registry imports `qs.Modules.Bar.Widgets` (`:6`), so no import change is
needed.

### 2c. `widgetMetadata` — only if the widget has settings (`:90-349`)

```qml
"Foo": {
  "iconColor": "none",
  "showLabel": true
}
```

This entry is the **persistence schema**:

- serves as the default when the user's entry lacks the key
  (`upgradeWidget()` injects it, `Commons/Settings.qml:1375-1385`),
- **unknown keys in a user's entry get deleted** on load
  (`Commons/Settings.qml:1366-1373`) — so every setting key must be listed
  here or it won't persist,
- its presence is what makes `widgetHasUserSettings("Foo")` true
  (`BarWidgetRegistry.qml:463-465`), which enables the settings dialog.

Omit it entirely for a widget with no settings.

> Do **not** put numeric slider bounds here — use `widgetSettingBounds`
> (`:51-56`). Rationale: metadata is written into users' settings files as if
> the value were user-chosen (`BarWidgetRegistry.qml:45-50`).

### 2d. `widgetSettingsMap` — only if a settings panel exists (`:57-88`)

```qml
"Foo": "WidgetSettings/FooSettings.qml",
```

Path is relative to `Modules/Panels/Settings/Bar/`.

---

## Step 3 — _(Optional)_ Settings panel

**Path: `Modules/Panels/Settings/Bar/WidgetSettings/FooSettings.qml`**

Copy an existing simple panel (e.g. `NightLightSettings.qml` or
`DarkModeSettings.qml`) and adapt. The dialog contract
(`BarWidgetSettingsDialog.qml`) expects the panel to expose:

- `screen`, `widgetData`, `widgetMetadata` properties
- a `settingsChanged(var)` signal
- a `saveSettings()` function that **returns** the settings object

Only add this if you declared `widgetMetadata` in step 2c.

---

## Step 4 — _(Optional)_ Add to default layout

**File: `Assets/settings-default.json`** → `bar.widgets`:

```json
"right": [ { "id": "Tray" }, { "id": "Foo" }, ... ]
```

- Needed only for it to appear **out of the box** for new users.
- Existing users add it themselves via **Settings → Bar → Widgets**
  (drag-and-drop between left/center/right).
- The entry's position in the array is its order; the array it's in is its
  zone.

---

## Step 5 — Validate

```bash
# Format all QML (required; lefthook also runs this on commit)
./Scripts/dev/qmlfmt.sh

# Rebuild settings search index (required if you added settings UI text)
python3 Scripts/dev/build-settings-search-index.py

# Full pre-commit (format + index)
lefthook run pre-commit

# Optional lint (needs dev shell for qmllint)
nix develop -c qmllint Modules/Bar/Widgets/Foo.qml
```

Quickshell **hot-reloads QML on save** — no `nix build` needed for this kind of
change (see `../AGENTS.md`). To run against the live tree:

```bash
QS_CONFIG_PATH=~/.config/quickshell/mordial-shell mordial-shell
# or
qs -c mordial-shell
```

If you added a brand-new widget and it doesn't show up in the settings
"available widgets" list, restart the shell — the registry is a singleton
built at startup.

---

## Checklist

- [ ] `Modules/Bar/Widgets/Foo.qml` exists, file name == widget ID
- [ ] Declares `screen`, `widgetId`, `section`, `sectionWidgetIndex`, `sectionWidgetsCount`
- [ ] Declares `widgetMetadata` / `screenName` / `widgetSettings` trio (if it has settings)
- [ ] Each setting resolved as `widgetSettings.x !== undefined ? widgetSettings.x : widgetMetadata.x`
- [ ] Sensible `implicitWidth` / `implicitHeight`
- [ ] Registered in `BarWidgetRegistry.widgets` + a `Component` property
- [ ] `widgetMetadata` entry covers **every** persisted setting key (or omitted if none)
- [ ] `widgetSettingsMap` entry + `WidgetSettings/FooSettings.qml` (if it has settings)
- [ ] Right-click menu offers "Widget settings" → `BarService.openWidgetSettings(...)`
- [ ] _(Optional)_ added to `Assets/settings-default.json` `bar.widgets`
- [ ] `./Scripts/dev/qmlfmt.sh` run
- [ ] `python3 Scripts/dev/build-settings-search-index.py` run (if settings changed)
- [ ] Tested: widget renders, left/right click work, reorder in settings works,
      settings persist across restart, per-screen layout works if relevant

---

## Troubleshooting

| Symptom                                                    | Likely cause                                                                                                                                                                                                                                                                     |
| ---------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Widget never appears / logs `Widget not found in registry` | Missing from `BarWidgetRegistry.widgets` (`BarWidgetLoader.qml:156-160`), or file name ≠ ID (loader builds the path from the ID, `BarWidgetLoader.qml:71-83`).                                                                                                                   |
| Settings reset to defaults on restart                      | Key missing from `widgetMetadata` — `upgradeWidget()` deletes unknown keys (`Commons/Settings.qml:1367-1375`).                                                                                                                                                                   |
| Entry disappears from layout on restart                    | ID not in registry — pruned at `Commons/Settings.qml:1296`.                                                                                                                                                                                                                      |
| "Widget settings" menu item does nothing / dialog blank    | Missing `widgetSettingsMap` entry, or panel path wrong (relative to `Modules/Panels/Settings/Bar/`).                                                                                                                                                                             |
| Widget renders but has no space / can't be clicked         | `opacity: 0` collapses layout (`BarWidgetLoader.qml:42-43`); or you overrode the cross-axis size the loader sets (`:114-125`).                                                                                                                                                   |
| Settings UI slider rejects a value                         | Value outside `widgetSettingBounds` (`BarWidgetRegistry.qml:51-56`).                                                                                                                                                                                                             |
| Bar doesn't pick up add/remove/reorder                     | Something changed settings without bumping `BarService.widgetsRevision` — the settings UI helpers do it for add/remove/reorder/move (`BarTab.qml:29-43`, `:45-57`, `:59-69`, `:77-90`); custom code must bump it too. Note settings-only edits intentionally do **not** bump it. |

---

## Removing a widget

Reverse order:

1. Remove its entry from `Assets/settings-default.json` (if present).
2. Remove `widgetMetadata` / `widgetSettingsMap` / `widgets` / `Component`
   entries from `BarWidgetRegistry.qml`.
3. Delete `Modules/Bar/Widgets/<Id>.qml` and
   `Modules/Panels/Settings/Bar/WidgetSettings/<Id>Settings.qml`.

Existing users' stale entries are auto-pruned on next load
(`Commons/Settings.qml:1296`), so no migration is needed.
