# Desktop Widgets — How They Work

How Mordial's floating desktop widgets are registered, placed, loaded, and
configured. Desktop widgets are the free-positioned widgets on the desktop,
distinct from bar widgets (documented in [`bar-widgets.md`](bar-widgets.md)).
Steps to add one: [`adding-a-desktop-widget.md`](adding-a-desktop-widget.md).

All paths are relative to the repo root. Line numbers are exact at the time of
writing — treat them as pointers, not contracts.

---

## 1. Mental model

```
settings.json: desktopWidgets.monitorWidgets
      │  [ { name: "DP-1", widgets: [ {id:"Clock", x:50, y:50, scale:1, ...settings} ] } ]
      ▼
Commons/Settings.qml  JsonObject desktopWidgets  (:835-842)
      ▼
Modules/DesktopWidgets/DesktopWidgets.qml  (Variants over Quickshell.screens)
      │  per monitor: transparent Bottom-layer PanelWindow with an input mask
      ▼  Repeater → Loader.setSource(DesktopWidgetRegistry.widgetUrls[id], props)
Modules/DesktopWidgets/Widgets/Desktop<Name>.qml   (root = DraggableDesktopWidget)
      ▼
Services/UI/DesktopWidgetRegistry.qml   (existence + metadata + settings map + URLs)
```

The headline difference from the bar: **position is absolute `x`/`y`/`scale`
stored per instance**, not an index in a zone array; and widgets live on a
transparent full-screen **LayerShell surface on the Bottom layer** whose input
is restricted to a per-widget `Region` mask.

---

## 2. What defines a desktop widget

There is no base class, `qmldir`, or manifest. A widget is:

1. an ordinary QML file at `Modules/DesktopWidgets/Widgets/Desktop<Name>.qml`,
2. registered by ID + URL in `DesktopWidgetRegistry` (§2.1),
3. rooted in `DraggableDesktopWidget` (§2.2).

### 2.1 The registry — `Services/UI/DesktopWidgetRegistry.qml`

A `pragma Singleton` (`:1-8`). Unlike `BarWidgetRegistry`, its `widgets` map is
a **presence map only** (`id → true`), and file URLs live in a separate
`widgetUrls` map — the comment at `:13-21` explains this avoids a
`Services.UI ↔ Widgets` circular import.

| Member | Lines | Purpose |
|---|---|---|
| `editMode` | `:11` | Transient (not persisted) edit-mode flag; drives drag/resize/overlay. |
| `widgets` | `:13-17` | `id → true`. Presence map for `in` checks and key iteration. |
| `widgetUrls` | `:23` | `id → file URL`. Actual load source. |
| `Component.onCompleted` | `:25-41` | **Registration site.** Builds both maps. |
| `widgetSettingsMap` | `:43-49` | `id → settings QML path`, relative to `Modules/Panels/Settings/DesktopWidgets/`. |
| `widgetMetadata` | `:51-90` | `id → default settings` schema. |
| `cpuIntensiveWidgets` | `:92` | `["SystemStat", "AudioVisualizer"]` — drives the "CPU" badge. |
| `updateWidgetData()` | `:130-151` | Immutably rewrites one instance's settings in `Settings.data.desktopWidgets.monitorWidgets`. |
| `openWidgetSettings()` | `:155-227` | Creates `DesktopWidgetSettingsDialog` on the screen's popup window. |
| helpers | `:94-126` | `init()` `:94`, `getWidget(id)` `:100` (dead — returns `true`/`null`), `hasWidget(id)` `:105`, `getAvailableWidgets()` `:110-114`, `widgetHasUserSettings(id)` `:117`, `isCpuIntensive(id)` `:121`, `getWidgetDisplayName(id)` `:126` (identity). |

Registration (`:25-41`):

```qml
Component.onCompleted: {
  var urlsObj = {};
  urlsObj["Clock"] = _widgetsDir + "DesktopClock.qml";
  urlsObj["MediaPlayer"] = _widgetsDir + "DesktopMediaPlayer.qml";
  urlsObj["Weather"] = _widgetsDir + "DesktopWeather.qml";
  urlsObj["SystemStat"] = _widgetsDir + "DesktopSystemStat.qml";
  urlsObj["AudioVisualizer"] = _widgetsDir + "DesktopAudioVisualizer.qml";
  widgetUrls = urlsObj;

  var widgetsObj = {};
  for (var id in urlsObj) { widgetsObj[id] = true; }
  widgets = widgetsObj;
}
```

There are **5 widgets**, matching the 5 files in
`Modules/DesktopWidgets/Widgets/`. Adding one to `widgetUrls` is what makes it
appear in `getAvailableWidgets()` and therefore in the settings UI.

> Unlike `BarWidgetRegistry`, there is **no `widgetSettingBounds`** and **no
> inline `Component` map**. Widgets are loaded by URL (not by path string like
> the bar, and not by `Component`).

### 2.2 The property contract — `DraggableDesktopWidget.qml`

Every widget roots in `Modules/DesktopWidgets/DraggableDesktopWidget.qml`
(628 lines), which provides positioning, scaling, background, drag/resize, and
the right-click menu. The loader injects three properties before
`Component.onCompleted` (`DesktopWidgets.qml:294-298`):

```qml
// Modules/DesktopWidgets/DraggableDesktopWidget.qml:12-19
property ShellScreen screen
property var widgetData: null      // this instance's {id, x, y, scale, ...settings}
property int widgetIndex: -1       // position within the monitor's widgets[]

property real defaultX: 100
property real defaultY: 100

default property alias content: contentContainer.data
```

Key differences from the bar contract: there is **no `widgetId` property**
(the ID lives in `widgetData.id`), and the instance identity used for settings
writes is `screen.name` + `widgetIndex`.

The base resolves the two universal settings with metadata fallback
(`:25-27`):

```qml
readonly property var _metadata: widgetData?.id ? DesktopWidgetRegistry.widgetMetadata[widgetData.id] : null
property bool showBackground: widgetData.showBackground !== undefined ? widgetData.showBackground : (_metadata?.showBackground ?? true)
property bool roundedCorners: widgetData.roundedCorners !== undefined ? widgetData.roundedCorners : (_metadata?.roundedCorners ?? true)
```

A concrete widget must:

1. Root in `DraggableDesktopWidget`.
2. Put visible content in child items — the `default property alias` (`:19`)
   routes them into `contentContainer` (`:321`).
3. Declare `implicitWidth` / `implicitHeight` and bind `width`/`height` to them,
   **multiplying every dimension by `widgetScale`** (scaling is done by
   dimension math, not the `scale` transform) — e.g.
   `Modules/DesktopWidgets/Widgets/DesktopClock.qml:24-28`.
4. Optionally declare `widgetMetadata` and resolve each setting as
   user-value-over-default (pattern: `DesktopClock.qml:13-22`).
5. Optionally override `defaultX`/`defaultY` for first-run placement.

`DraggableDesktopWidget` also provides `widgetScale` (`:29`, default 1.0;
`minScale` 0.5 / `maxScale` 5.0 at `:30-31`).

---

## 3. Render pipeline — settings → pixels

### 3.1 Container — `Modules/DesktopWidgets/DesktopWidgets.qml` (522 lines)

Instantiated once at shell root: `shell.qml:120` (`DesktopWidgets {}`).

- `Variants { model: Quickshell.screens }` (`:12-14`) → one delegate per monitor.
- `registeredWidgets` (`:17`) binds to `DesktopWidgetRegistry.widgets`.
- Per-monitor list — reactive, rebuilt from settings (`:25-36`):

```qml
property var screenWidgets: {
  if (!modelData || !modelData.name) return [];
  var monitorWidgets = Settings.data.desktopWidgets.monitorWidgets || [];
  for (var i = 0; i < monitorWidgets.length; i++)
    if (monitorWidgets[i].name === modelData.name) return monitorWidgets[i].widgets || [];
  return [];
}
```

- Activation gate (`:39`) — no surface is created for an empty monitor unless
  in edit mode, and never over the lock screen:

```qml
active: modelData && Settings.data.desktopWidgets.enabled
        && (screenWidgets.length > 0 || DesktopWidgetRegistry.editMode)
        && !PanelService.lockScreen?.active
```

- The LayerShell window (`:41-69`):

```qml
PanelWindow {
  color: "transparent"
  screen: screenLoader.modelData
  mask: DesktopWidgetRegistry.editMode ? null : widgetsMask
  Region { id: widgetsMask; regions: window._maskRegions }
  WlrLayershell.layer: WlrLayer.Bottom
  WlrLayershell.exclusionMode: ExclusionMode.Ignore
  WlrLayershell.namespace: "noctalia-desktop-widgets-" + (screen?.name || "unknown")
}
```

The `mask` is the whole interaction story:

- **Normal mode:** input is masked to `widgetsMask` — a `Region` (`:55-58`)
  built from `window._maskRegions` — so only widget rectangles receive input;
  the rest is click-through to the desktop.
- **Edit mode:** `mask: null` → the full-screen surface takes input so drag and
  resize areas work anywhere.

Mask regions are added in the widget loader's `onLoaded` (`:306-317`) and
removed in `onItemChanged` (`:320-329`).

### 3.2 Per-widget loader (inline, no separate file)

`Modules/DesktopWidgets/DesktopWidgets.qml:265-331`:

```qml
Repeater {
  model: screenLoader.screenWidgets
  delegate: Loader {
    active: (modelData.id in root.registeredWidgets)   // :271

    function _loadWidget() {                            // :288-304
      var widgetId = modelData.id;
      var comp = root.registeredWidgets[widgetId];
      if (!comp) return;
      var props = { "screen": window.screen, "widgetData": modelData, "widgetIndex": index };
      var url = DesktopWidgetRegistry.widgetUrls[widgetId];
      if (url) setSource(url, props);
    }
    Component.onCompleted: _loadWidget()
    onLoaded: { item.parent = widgetsContainer; /* create mask region */ }
  }
}
```

There is **no `DesktopWidgetLoader.qml`** — loading is inline. Props are passed
via `setSource()` so they exist during `Component.onCompleted` (comment at
`:277-280`).

### 3.3 Position, size, scale, z-order

- **Position** is absolute, stored per instance; the base binds it at
  `DraggableDesktopWidget.qml:258-259`:
  ```qml
  x: Math.round(internal.isDragging ? internal.dragOffsetX : internal.baseX)
  y: Math.round(internal.isDragging ? internal.dragOffsetY : internal.baseY)
  ```
  with `baseX` initialized from `widgetData.x` / `defaultX` (`:237`, `:274`).
- **Size** from the widget's own `implicitWidth`/`implicitHeight × widgetScale`
  (`DesktopClock.qml:25-28`).
- **Scale** is the per-instance `widgetScale` (`:29-31`), persisted to
  `widgetData.scale` on resize.
- **Z-order** is array order (later siblings paint on top). `raiseToTop()`
  (`:177`) moves the widget to the end of the monitor's array; `lowerToBottom()`
  (`:201`) to the front.
- **Grid snap:** `snapToGrid()` (`:111`) / `snapScaleToGrid()` (`:118`), gated on
  `Settings.data.desktopWidgets.gridSnap` / `gridSnapScale`.

### 3.4 Reactivity — no revision counter

Unlike the bar (`BarService.widgetsRevision`, see `bar-widgets.md`), desktop
widgets have **no revision counter and no dedicated service**. They rely on
direct reactive bindings:

- `DesktopWidgets.qml:25-36` recomputes `screenWidgets` when settings change.
- `DesktopWidgets.qml:17` binds `registeredWidgets` for registry changes.
- `DraggableDesktopWidget.qml:272-283` refreshes from `widgetData` changes.

### 3.5 Editing (drag / resize / context menu)

All in `DraggableDesktopWidget.qml`:

- `dragArea` (`:367-452`) — left-drag, only in edit mode; clamped so 75% of the
  widget stays on screen; snaps to grid; persists `{x,y}` on release.
- `contextMenuArea` (`:454-475`) — right-click →
  `PopupMenuWindow.showDynamicContextMenu(...)`. Menu model at `:328-364`:
  "Widget settings" (only if in `widgetSettingsMap`), "Reset", "Raise to top",
  "Lower to bottom", "Delete". Dispatched by `handleContextMenuAction()`
  (`:229`).
- Corner resize handles — `cornerHandleModel` (`:485-519`) + `Repeater`
  (`:520-628`), each a `MouseArea` with diagonal-projection scale math;
  persists `scale` on release.
- Decoration (`:286`, `decorationRect`), background (`:297`, `container`, with
  shadow), content host (`:321`, `contentContainer`).

The edit-mode controls panel (`DesktopWidgets.qml:334-518`) offers Add widget,
grid-snap toggles, Open settings, and Exit edit mode. The grid overlay is a
`Canvas` shown only when `editMode && enabled && gridSnap`
(`DesktopWidgets.qml:130-262`).

`addWidgetToCurrentScreen(widgetId)` (`DesktopWidgets.qml:76-122`) copies
defaults from `widgetMetadata`, centers the new widget, and appends it to the
monitor's array in settings.

---

## 4. Settings integration

### 4.1 Where config lives

Two distinct places:

1. **Instance/layout config** — `Settings.data.desktopWidgets`, a `JsonObject`
   at `Commons/Settings.qml:835-842`:

   ```qml
   property JsonObject desktopWidgets: JsonObject {
     property bool enabled: false
     property bool overviewEnabled: true
     property bool gridSnap: false
     property bool gridSnapScale: false
     property list<var> monitorWidgets: []   // [{name, widgets:[{id,x,y,scale,...}]}]
   }
   ```

   Runtime shape:

   ```json
   "desktopWidgets": {
     "enabled": false,
     "overviewEnabled": true,
     "gridSnap": false,
     "gridSnapScale": false,
     "monitorWidgets": [
       { "name": "DP-1",
         "widgets": [ { "id": "Clock", "x": 50, "y": 50, "scale": 1.0,
                        "showBackground": true, "roundedCorners": true,
                        "clockStyle": "digital", "format": "HH:mm\\nd MMMM yyyy" } ] }
     ]
   }
   ```

   Defaults: `Assets/settings-default.json:548-554`.

2. **Default schema** — `DesktopWidgetRegistry.widgetMetadata` (`:51-90`).
   Used at add-time (`DesktopWidgets.qml:83-88`, `DesktopWidgetsTab.qml`) and
   by widget-side fallbacks.

> `Assets/settings-widgets-default.json` has a `"desktop"` section too, but it
> is a **generated reference artifact**, not read at runtime. It is written by
> `Commons/Settings.qml:1165-1182` from the registries and self-heals on the
> next shell run. Trust the registry, not this file.

### 4.2 Migration is prune-only

`upgradeSettings()` (`Commons/Settings.qml:1277-1354`) does three prunes and one
upgrade pass. The desktop-widget prune is at `:1320-1335`:

```qml
const monitorWidgets = adapter.desktopWidgets.monitorWidgets;
for (var m = 0; m < monitorWidgets.length; m++) {
  const monitor = monitorWidgets[m];
  if (!monitor.widgets) continue;
  for (var i = monitor.widgets.length - 1; i >= 0; i--) {
    var desktopWidget = monitor.widgets[i];
    if (!DesktopWidgetRegistry.hasWidget(desktopWidget.id)) {
      Logger.w(`Settings`, `!!! Deleted invalid desktop widget ${desktopWidget.id} !!!`);
      monitor.widgets.splice(i, 1);
    }
  }
}
```

**So: register a widget before adding it to anyone's layout, or their entry is
deleted on next load.**

There is **no `upgradeDesktopWidget()`** — unlike bar widgets, desktop widget
keys are never pruned or back-filled from metadata (`upgradeWidget()`,
`Commons/Settings.qml:1358-1390`, is bar-only). Defaults are applied only at
add-time. Migration defers itself until the registry is ready
(`:1279-1283` retries via `Qt.callLater`).

### 4.3 Settings UI

| Piece | Path | Role |
|---|---|---|
| Tab | `Modules/Panels/Settings/Tabs/DesktopWidgetsTab.qml` (292 lines) | toggles `:21-38`, edit-mode button `:47-66`, one `NSectionEditor` per monitor `:69-101` (`draggable:false`), available list from `getAvailableWidgets()` `:150`, helpers `_addWidgetToMonitor` `:214`, `_removeWidgetFromMonitor` `:249`, `_updateWidgetSettingsForMonitor` `:258`, `_moveWidgetToMonitor` `:267` |
| Dialog | `Modules/Panels/Settings/DesktopWidgets/DesktopWidgetSettingsDialog.qml` (230 lines) | per-widget `Popup`, loads panel from `widgetSettingsMap`, debounced save |
| Panels | `Modules/Panels/Settings/DesktopWidgets/WidgetSettings/<Id>Settings.qml` | 5 panels (AudioVisualizer, Clock, MediaPlayer, SystemStat, Weather) |
| Nav mount | `Modules/Panels/Settings/SettingsContent.qml:560`, `:602` | mounts the tab + nav entry |
| Enum | `Modules/Panels/Settings/SettingsPanel.qml:22` | `DesktopWidgets` tab enum |

Desktop widgets are positioned by x/y, not list order, so the tab's
`NSectionEditor`s use `draggable: false, crossSectionDraggable: true`; moving a
widget to another monitor resets `x=100, y=100, scale=1.0`.

---

## 5. Interactivity

### Clicks
- Normal mode: widgets receive input only inside their mask region
  (`DesktopWidgets.qml:45`, `:311-315`); each widget implements its own
  controls, e.g. `Modules/DesktopWidgets/Widgets/DesktopMediaPlayer.qml:254`
  (`NIconButton` → `MediaService.*`).
- Edit mode: the base's `dragArea` (`z:1000`) and `contextMenuArea` (`z:1001`)
  capture clicks, so widget content is inert while editing.

### Focus / popups
A Bottom-layer surface can't take keyboard input, so settings dialogs and
context menus are created in `PopupMenuWindow` (Top layer):
`DesktopWidgetRegistry.openWidgetSettings()` uses
`PanelService.getPopupMenuWindow(screen)` (`:190`) and toggles
`popupMenuWindow.hasDialog` (`:216`, `:218`), which gates
`WlrLayershell.keyboardFocus` in `Modules/MainScreen/PopupMenuWindow.qml:36`.
Popup windows are force-created on all screens while edit mode is active
(`Modules/MainScreen/AllScreens.qml:138-142`).

### IPC
- **`desktopWidgets` target** (`Services/Control/IPCService.qml:863-878`):
  `toggle`, `enable`, `disable`, `edit` (toggles
  `DesktopWidgetRegistry.editMode`). Documented in `IPC.md:49-52`.
- No desktop widget currently exposes per-instance IPC. The `pomodoro` target
  (`Services/Control/PomodoroIPCService.qml`, documented in `IPC.md:179+`) still
  exists but is driven by the **bar** `Pomodoro` widget
  (`Modules/Bar/Widgets/Pomodoro.qml:110-113`);
  `PomodoroIPCService.init()` is force-called at `shell.qml:106`.

> Per AGENTS.md: when adding/removing/renaming an IPC handler or changing its
> args, update the matching table in `IPC.md`.

---

## 6. Existing widgets

All in `Modules/DesktopWidgets/Widgets/`:

| File | Lines | Purpose | Mirrors bar widget |
|---|---|---|---|
| `DesktopClock.qml` | 81 | Digital/minimal clock + date. **Shortest — best template.** | `Clock` |
| `DesktopWeather.qml` | 146 | Temp, H/L, location, icon from `LocationService`. No user settings. | — |
| `DesktopAudioVisualizer.qml` | 119 | Audio spectrum bars via `SpectrumService`. CPU-intensive. | `AudioVisualizer` |
| `DesktopSystemStat.qml` | 305 | CPU/GPU/Memory/Disk gauges. CPU-intensive. | `SystemMonitor` |
| `DesktopMediaPlayer.qml` | 311 | Album art, title/artist, transport controls. | `MediaMini` |

`DesktopClock.qml` is the structural model (`base → widgetMetadata → resolved
settings → implicit size → content`); `DesktopWeather.qml` is the
"no-user-settings" variant.

---

## 7. Shared components

`Modules/DesktopWidgets/` contains two shared files plus `Widgets/`:

| Component | Path | Role |
|---|---|---|
| `DraggableDesktopWidget` | `Modules/DesktopWidgets/DraggableDesktopWidget.qml` (628 lines) | Base for every widget: position `:258-259`, scale `:29-31` / `:485-628`, background & decorations `:286-325`, drag `:367-452`, context menu `:328-364` / `:454-475`, raise/lower/delete `:177-256`, grid snap `:111-145` |
| `DesktopWidgets` | `Modules/DesktopWidgets/DesktopWidgets.qml` (522 lines) | Per-monitor container: LayerShell window + input mask `:41-69`, grid overlay `:130-262`, widget loaders `:265-331`, edit controls panel `:334-518` |
| `Widgets/` | 5 files | The widgets themselves (§6) |

There is **no** `DesktopWidgetContainer`, no edit-mode overlay component, and no
`DesktopWidgetLoader` — all of that lives inside the two files above.

---

## 8. Naming conventions

1. **Widget file:** `Desktop<Name>.qml`; **registry key is `<Name>`** (no
   `Desktop` prefix). The URL is built from the key: `Desktop + id + ".qml"`.
2. **Settings panel:** `WidgetSettings/<Name>Settings.qml`.
3. **Settings keys are camelCase** (`showBackground`, `clockStyle`).
4. **Instance identity** for settings writes is `screen.name` + `widgetIndex`.
5. **Color settings use `"none"`** and resolve via `Color.resolveColorKey(key)`.

---

## 9. Desktop vs bar widgets

| Aspect | Bar (see `bar-widgets.md`) | Desktop |
|---|---|---|
| Registry | `widgets` maps id → inline `Component`; has `widgetSettingBounds` | `widgets` maps id → `true`; file URLs in separate `widgetUrls`; **no bounds map** |
| Loading | `BarWidgetLoader` loads by path `<dir>/<id>.qml` | inline `Loader.setSource(widgetUrls[id])`; **no loader file** |
| Injected props | `screen`, `widgetId`, `section`, `sectionWidgetIndex`, `sectionWidgetsCount` | `screen`, `widgetData`, `widgetIndex` (**no `widgetId`**) |
| Position | order within `left`/`center`/`right` arrays | absolute `x`/`y`/`scale` per instance |
| File naming | `Modules/Bar/Widgets/<Name>.qml` (ID == file name) | `Modules/DesktopWidgets/Widgets/Desktop<Name>.qml` (ID == name minus `Desktop`) |
| Surface | one bar layer-shell window per screen, RowLayout | transparent full-screen Bottom-layer window + per-widget input `Region` mask |
| Base | none formal; 3 presentation patterns | `DraggableDesktopWidget` (drag/resize/menu/scale) |
| Reactivity | `BarService.widgetsRevision` on structure change | **no revision**; direct bindings to settings |
| Migration | prune + `upgradeWidget()` (prunes/injects keys) | **prune only**; no key upgrade |
| Instance registry | `BarService.registerWidget` + lookup API | none generic |
| Settings tab | `BarTab.qml` + `WidgetsSubTab`/`MonitorsSubTab` | `DesktopWidgetsTab.qml` (one `NSectionEditor` per monitor) |

---

## 10. Known gotchas

- **Register before adding to a layout** — unregistered IDs are pruned from user
  settings on load (`Commons/Settings.qml:1329`).
- **No key migration.** Unlike bar widgets, unknown/legacy desktop widget
  setting keys are **not** pruned and missing defaults are **not** injected —
  defaults only land at add-time. Widgets must fall back defensively.
- **Scaling is dimension math,** not the `scale` transform — every size in a
  widget must be multiplied by `widgetScale` (see `DesktopClock.qml:16`).
- **`overviewEnabled`** (`Commons/Settings.qml:837`, toggle at
  `DesktopWidgetsTab.qml`) appears currently unwired — no consumer found.
- **`getWidget()` is dead code** — returns `true`/`null`, never a Component
  (`DesktopWidgetRegistry.qml:100-102`).
- **Vestigial plugin comment** at `DesktopWidgetRegistry.qml:19-21` (plugin
  system removed, `Commons/Settings.qml:1251-1255`).
- **Layer-shell namespace still branded** `"noctalia-desktop-widgets-<screen>"`
  (`DesktopWidgets.qml:62`) — leftover from the upstream fork.
