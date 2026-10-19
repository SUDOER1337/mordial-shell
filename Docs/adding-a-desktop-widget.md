# Adding a Desktop Widget — Step-by-Step

Companion to [`desktop-widgets.md`](desktop-widgets.md), which explains the
machinery. This is the checklist for shipping a new desktop widget.

We'll build a hypothetical widget called **`Foo`**.

---

## TL;DR

1. Create `Modules/DesktopWidgets/Widgets/DesktopFoo.qml` rooted in
   `DraggableDesktopWidget`, with content and `implicitWidth`/`implicitHeight`
   scaled by `widgetScale`.
2. Register it in `Services/UI/DesktopWidgetRegistry.qml`
   (`Component.onCompleted` → `widgetUrls`/`widgets`), plus `widgetMetadata` /
   `widgetSettingsMap` if it has settings.
3. *(Optional)* add `Modules/Panels/Settings/DesktopWidgets/WidgetSettings/FooSettings.qml`.
4. Format and rebuild indexes.

No `qmldir`, no manifest, no loader file — the file + URL entry is the whole
contract.

---

## Step 1 — Create the widget file

**Path: `Modules/DesktopWidgets/Widgets/DesktopFoo.qml`** (registry key `Foo`,
file `DesktopFoo.qml`).

### Property contract

The base `DraggableDesktopWidget` supplies the standard properties; the loader
injects them (`Modules/DesktopWidgets/DesktopWidgets.qml:294-298`):

- `screen: ShellScreen`
- `widgetData: var` — this instance's `{id, x, y, scale, ...settings}`
- `widgetIndex: int`

You do **not** declare these yourself — you read them. There is **no
`widgetId`** property; the ID is `widgetData.id`.

### Template

```qml
import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Modules.DesktopWidgets
import qs.Services.UI
import qs.Widgets

DraggableDesktopWidget {
  id: root

  readonly property var widgetMetadata: DesktopWidgetRegistry.widgetMetadata["Foo"]

  // Resolve each setting: user value wins, else registry default
  readonly property string label: widgetData.label !== undefined ? widgetData.label : widgetMetadata.label
  readonly property color textColor: Color.resolveColorKey(widgetData.color !== undefined ? widgetData.color : widgetMetadata.color)

  // Content size × widgetScale (scaling is dimension math, not the scale transform)
  implicitWidth: Math.round(content.implicitWidth + Style.marginL * 2)
  implicitHeight: Math.round(content.implicitHeight + Style.marginL * 2)
  width: implicitWidth
  height: implicitHeight

  // Children land in contentContainer via the default property alias
  ColumnLayout {
    id: content
    anchors.centerIn: parent
    spacing: Style.marginS

    NText {
      text: root.label
      color: root.textColor
      font.pointSize: Math.round(Style.fontSizeL * root.widgetScale)
    }
  }
}
```

### Rules the template obeys

- **Content:** direct children go into `contentContainer` via the
  `default property alias content` (`DraggableDesktopWidget.qml:19`), which
  fills the widget (`:320-325`).
- **Scaling:** multiply every size by `widgetScale` (see
  `DesktopClock.qml:16`). The base does **not** apply a `scale` transform.
- **Background/rounded corners:** handled by the base from `showBackground` /
  `roundedCorners` (`DraggableDesktopWidget.qml:25-27`) — use
  `showBackground` in settings, don't draw your own.
- **First-run placement:** override `defaultX` / `defaultY` if the default
  (100, 100) is unsuitable.
- **User settings fallback:** prefer `widgetData.x !== undefined ? widgetData.x
  : widgetMetadata.x`.

---

## Step 2 — Register it

**File: `Services/UI/DesktopWidgetRegistry.qml`**

### 2a. `widgetUrls` / `widgets` — **required** (`:25-42`)

Add one line in `Component.onCompleted`:

```qml
urlsObj["Foo"] = _widgetsDir + "DesktopFoo.qml";
```

The `widgets` presence map is derived from `widgetUrls` automatically
(`:35-39`), so no second edit. Without this, `hasWidget("Foo")` is false and
the widget is:

- not available in the "Add widget" list (`getAvailableWidgets()`, `:127-131`),
- filtered out at load (`DesktopWidgets.qml:271`),
- **deleted from user layouts** on next load (`Commons/Settings.qml:1329`).

### 2b. `widgetMetadata` — only if the widget has settings (`:53-107`)

```qml
"Foo": {
  "showBackground": true,
  "roundedCorners": true,
  "label": "Hello",
  "color": "none"
}
```

Used as: the add-time default (`DesktopWidgets.qml:83-88`), the dialog's
`widgetMetadata` (`DesktopWidgetSettingsDialog.qml`), and widget-side fallbacks.
`showBackground`/`roundedCorners` are universal — include them if you want the
settings dialog to expose them.

> There is **no key migration** for desktop widgets: unknown keys aren't
> pruned and missing keys aren't injected after add-time. The widget must fall
> back defensively, and the settings panel must handle a missing key.

### 2c. `widgetSettingsMap` — only if a settings panel exists (`:44-51`)

```qml
"Foo": "WidgetSettings/FooSettings.qml",
```

Path is relative to `Modules/Panels/Settings/DesktopWidgets/`.

### 2d. `cpuIntensiveWidgets` — only if expensive (`:109`)

```qml
property var cpuIntensiveWidgets: ["SystemStat", "AudioVisualizer", "Foo"]
```

---

## Step 3 — *(Optional)* Settings panel

**Path: `Modules/Panels/Settings/DesktopWidgets/WidgetSettings/FooSettings.qml`**

The dialog loads it with initial properties `widgetData` and `widgetMetadata`
(`DesktopWidgetSettingsDialog.qml`, `loadWidgetSettings()`). Copy
`ClockSettings.qml` (shortest) and adapt. Required contract:

- `property var widgetData`
- `property var widgetMetadata`
- `signal settingsChanged(var settings)`
- `function saveSettings()` that calls `settingsChanged(merged)`

```qml
ColumnLayout {
  id: root
  property var widgetData: null
  property var widgetMetadata: null
  signal settingsChanged(var settings)

  property string valueLabel: widgetData.label !== undefined ? widgetData.label : widgetMetadata.label

  function saveSettings() {
    var settings = Object.assign({}, widgetData || {});
    settings.label = valueLabel;
    settingsChanged(settings);
  }

  NTextInput { /* ... bound to valueLabel ... */ }
}
```

Only add this if you declared `widgetMetadata` in step 2b.

---

## Step 4 — *(Optional)* IPC

If the widget needs commands (like `Pomodoro`), follow the `PomodoroIPCService`
pattern (`Services/Control/PomodoroIPCService.qml`):

1. Create `Services/Control/FooIPCService.qml` — a `pragma Singleton` with an
   instance registry (`registerFoo`/`unregisterFoo`) and an
   `IpcHandler { target: "foo" }`.
2. In the widget, register via a **child `QtObject`** so you don't clobber the
   base's own `Component.onCompleted`
   (`Modules/Bar/Widgets/Pomodoro.qml:110-113`):

   ```qml
   QtObject {
     id: ipcRegistration
     Component.onCompleted: FooIPCService.registerFoo(root)
     Component.onDestruction: FooIPCService.unregisterFoo(root)
   }
   ```
3. Force-instantiate at `shell.qml:106` (`FooIPCService.init();`).
4. Update the `foo` table in **`IPC.md`**.

---

## Step 5 — Validate

```bash
./Scripts/dev/qmlfmt.sh                              # format (lefthook also runs this)
python3 Scripts/dev/build-settings-search-index.py  # if you added settings UI text
lefthook run pre-commit
nix develop -c qmllint Modules/DesktopWidgets/Widgets/DesktopFoo.qml   # optional
```

Quickshell hot-reloads QML on save — no `nix build` needed for QML-only
changes (see `../AGENTS.md`).

Manual test:

```bash
qs ipc call desktopWidgets enable        # show desktop widgets
qs ipc call desktopWidgets edit          # enter edit mode (full-surface input)
# add "Foo" from the edit panel, drag/resize it, right-click → Widget settings
qs ipc call desktopWidgets edit          # exit edit mode
```

---

## Checklist

- [ ] `Modules/DesktopWidgets/Widgets/DesktopFoo.qml` exists, rooted in `DraggableDesktopWidget`
- [ ] Reads `screen` / `widgetData` / `widgetIndex` (no `widgetId` self-declaration)
- [ ] Declares `implicitWidth` / `implicitHeight`, every dimension × `widgetScale`
- [ ] `width`/`height` bound to implicit size
- [ ] Plays nicely with the base background (`showBackground` / `roundedCorners`)
- [ ] Registered in `DesktopWidgetRegistry.Component.onCompleted` → `urlsObj["Foo"]`
- [ ] `widgetMetadata` entry (with `showBackground`/`roundedCorners`) if it has settings
- [ ] `widgetSettingsMap` entry + `WidgetSettings/FooSettings.qml` if it has settings
- [ ] `cpuIntensiveWidgets` updated if it polls CPU/GPU/audio
- [ ] *(Optional)* `defaultX`/`defaultY` overridden
- [ ] *(Optional)* IPC service + child `QtObject` registration + `IPC.md` updated
- [ ] `./Scripts/dev/qmlfmt.sh` run
- [ ] `python3 Scripts/dev/build-settings-search-index.py` run (if settings changed)
- [ ] Tested: renders, drags, resizes, right-click menu works, settings persist
      across restart, per-monitor placement works

---

## Troubleshooting

| Symptom | Cause / fix |
|---|---|
| Widget never appears in "Add widget" | Missing from `Component.onCompleted` `urlsObj` (`DesktopWidgetRegistry.qml:25-42`). |
| Entry disappears from layout on restart | ID not registered — pruned at `Commons/Settings.qml:1329`. |
| No settings dialog / context item | Missing `widgetSettingsMap` entry, or panel path wrong (relative to `Modules/Panels/Settings/DesktopWidgets/`). |
| Widget can't be clicked in normal mode | Its mask region wasn't created (widget failed to load, or `active` was false — `DesktopWidgets.qml:271`). |
| Widget ignores the mouse entirely | Not in `registeredWidgets`; check the ID matches `Desktop<Name>.qml`. |
| Sizes look wrong when scaling | You didn't multiply a dimension by `widgetScale` (base scales via dimension math, not the `scale` transform). |
| Settings reset to defaults after restart | Desktop widgets have no key back-fill — read with a metadata fallback, and persist keys your panel writes. |
| Background drawn twice | You drew your own background; use `showBackground` and let the base render it (`DraggableDesktopWidget.qml:296-318`). |
| Widget is inert while editing | Expected: the base's drag/context areas capture input in edit mode. |

---

## Removing a desktop widget

1. Remove the `urlsObj["Foo"] = ...` line in
   `Services/UI/DesktopWidgetRegistry.qml:25-42`.
2. Remove its `widgetMetadata` / `widgetSettingsMap` / (if any) `cpuIntensiveWidgets`
   entries.
3. Delete `Modules/DesktopWidgets/Widgets/DesktopFoo.qml` and
   `Modules/Panels/Settings/DesktopWidgets/WidgetSettings/FooSettings.qml`.

Existing users' stale entries are auto-pruned on next load
(`Commons/Settings.qml:1329`), so no migration is needed.
