# Bar Widgets — How They Work

How Mordial's top bar assembles, loads, and configures its widgets. For the
how-to, see [`adding-a-bar-widget.md`](adding-a-bar-widget.md).

All paths are relative to the repo root. Line numbers are exact at the time of
writing — treat them as pointers, not contracts.

---

## 1. What defines a widget

There is **no base class, no `qmldir`, and no JSON manifest**. A widget is
simply an ordinary QML file at `Modules/Bar/Widgets/<Name>.qml` that satisfies
two things:

1. **A property contract** — the standard set of properties the bar passes in
   and reads back (see §1.2).
2. **A registry entry** — an ID listed in the `widgets` map of
   `Services/UI/BarWidgetRegistry.qml` (§1.1).

The **widget ID is the one name shared everywhere**:

```
ID  ==  file name  ==  registry key  ==  widgetMetadata key  ==  widgetSettingsMap key
e.g. "Clock"  ==  Modules/Bar/Widgets/Clock.qml  ==  "Clock" in all four registry maps
```

Because `BarWidgetLoader` loads widgets **by path** (`<dir>/<widgetId>.qml`),
a mismatch between the registry key and the file name is a silent no-op.

### 1.1 The registry — `Services/UI/BarWidgetRegistry.qml`

A `pragma Singleton` (`Services/UI/BarWidgetRegistry.qml:1-9`) that is the
single source of truth for "which widgets exist". It holds four maps plus
inline `Component` declarations:

| Member | Lines | Purpose |
|---|---|---|
| `widgets` | `:12-43` | widget ID → inline `Component`. Membership here **defines** a widget. |
| `widgetSettingBounds` | `:51-56` | numeric slider min/max per widget+setting, kept **out** of metadata on purpose — metadata is the persistence schema, a bound declared there would be written into every user's settings file as a chosen value (see comment at `:45-50`). |
| `widgetSettingsMap` | `:57-88` | widget ID → settings-dialog QML path, relative to `Modules/Panels/Settings/Bar/`. |
| `widgetMetadata` | `:90-349` | widget ID → default settings schema. Drives defaults, migration, and whether "Widget settings" appears. |
| Component props | `:352-441` | one `property Component <x>Component: Component { <Name> {} }` per widget. |
| helpers | `:448-471` | `getWidget(id)` `:448`, `hasWidget(id)` `:453`, `getAvailableWidgets()` `:458-460`, `widgetHasUserSettings(id)` `:463-465`, `cpuIntensiveWidgets` `:467`, `isCpuIntensive(id)` `:469-471`. |

```qml
// Services/UI/BarWidgetRegistry.qml:12-43 (abridged)
property var widgets: ({
  "ActiveWindow": activeWindowComponent,
  "AudioVisualizer": audioVisualizerComponent,
  "Battery": batteryComponent,
  ...
  "Workspace": workspaceComponent
})
```

```qml
// Services/UI/BarWidgetRegistry.qml:458-460
function getAvailableWidgets() {
  return Object.keys(widgets);
}
```

`getAvailableWidgets()` feeds the settings panel's "add widget" list
(`Modules/Panels/Settings/Tabs/Bar/BarTab.qml:130-139`), so registering a
widget is what makes it discoverable to the user.

There are currently **30 widgets**, matching the 30 files in
`Modules/Bar/Widgets/` and the 30 entries in `widgetSettingsMap`.

> **Note:** the registry's `Component` entries are *not* what instantiates
> widgets at runtime — `BarWidgetLoader` loads by file path instead (§3.2).
> They exist so the singleton can resolve/import the type and serve
> `getWidget()`.

### 1.2 The property contract

Every widget must declare these, because `BarWidgetLoader` injects them as
initial properties before `Component.onCompleted`
(`Modules/Bar/Extras/BarWidgetLoader.qml:61-69`):

```qml
property ShellScreen screen
property string widgetId: ""
property string section: ""              // "left" | "center" | "right"
property int sectionWidgetIndex: -1       // position within its section array
property int sectionWidgetsCount: 0
```

Plus the standard resolution trio every widget repeats
(e.g. `Modules/Bar/Widgets/Clock.qml:23-33`, `Modules/Bar/Widgets/NightLight.qml:23-33`):

```qml
property var widgetMetadata: BarWidgetRegistry.widgetMetadata[widgetId] ?? {}
readonly property string screenName: screen ? screen.name : ""
property var widgetSettings: {
  if (section && sectionWidgetIndex >= 0 && screenName) {
    var widgets = Settings.getBarWidgetsForScreen(screenName)[section];
    if (widgets && sectionWidgetIndex < widgets.length)
      return widgets[sectionWidgetIndex];
  }
  return {};
}
```

`widgetSettings` is the **per-instance** settings object (this widget, in this
section, on this screen); `widgetMetadata` is the **defaults** from the
registry. Individual settings then resolve user-value-over-default:

```qml
// Modules/Bar/Widgets/Clock.qml:44-49 (pattern repeated per setting)
readonly property string formatHorizontal:
  widgetSettings.formatHorizontal !== undefined ? widgetSettings.formatHorizontal : widgetMetadata.formatHorizontal
```

Other implicit expectations:

- **`implicitWidth` / `implicitHeight`** — your content size. The loader
  overrides the *cross-axis* dimension to fill the bar for extended click
  areas (`BarWidgetLoader.qml:114-125`), so declare content size and let the
  loader stretch the other axis.
- **`opacity`** — a widget whose root has `opacity: 0` is removed from layout
  entirely (`BarWidgetLoader.qml:42-43`). Optionally expose `hideMode` with
  value `"transparent"` to opt back into occupying space.
- **`onLoaded()`** — optional hook; the loader calls it after registration if
  present (`BarWidgetLoader.qml:144-147`).
- **`clicked()`** — optional function; hot corners in the bar invoke it on the
  first/last widget of a section (`Modules/Bar/Bar.qml:33-59`).

---

## 2. Presentation bases

There is no formal hierarchy, but every widget is rooted in one of three ways
(verified by grep over all 30 files):

### A. Root is `NIconButton` — fixed square button (9 widgets)
`Widgets/NIconButton.qml:10-43` exposes `baseSize`, `icon`, `colorBg`/`colorFg`,
`tooltipText`, `tooltipDirection`, `hoverOpensPanel`, and signals
`entered/exited/clicked/rightClicked/middleClicked/wheel`.

**DarkMode, Dashboard, Launcher, NightLight, NotificationHistory, PowerProfile,
SessionMenu, Settings, WallpaperSelector.**
`Modules/Bar/Widgets/NightLight.qml` (90 lines) is the shortest complete
example and the best template for this style.

### B. Root is `Item` containing a `BarPill` — icon + expanding text (11 widgets)
`Modules/Bar/Extras/BarPill.qml:6-34` exposes `icon`, `text`, `suffix`,
hover-expand behavior (`autoHide`/`forceOpen`/`forceClose`), colors, and the
same click signals. It delegates to `BarPillHorizontal` / `BarPillVertical`
through a Loader so one component serves both bar orientations
(`BarPill.qml:41-45` sizing: content axis from the pill, cross axis fills
parent).

**Battery, Bluetooth, Brightness, CustomButton, KeepAwake, KeyboardLayout,
Microphone, Network, Pomodoro, Volume, VPN.** The widget root stays an `Item` (it needs
room for both orientations and settings resolution) and nests a `BarPill`
inside.

### C. Root is `Item` with custom layout (10 widgets)
Used when the widget needs fully custom rendering: ActiveWindow, AudioVisualizer,
Clock, LockKeys, MediaMini, Spacer, SystemMonitor, Taskbar, Tray, Workspace.
These wire their own `MouseArea` (e.g. `Modules/Bar/Widgets/Clock.qml:186-220`).

**Pill convention:** widgets using `BarPill` typically normalize an explicit
`displayMode` of `onhover` | `graphic` | `graphic-clean` and read it from
settings (e.g. `Modules/Bar/Widgets/Battery.qml`).

---

## 3. Render pipeline — settings → pixels

```
Assets/settings-default.json        bar.widgets.{left,center,right} = [{id:...}, ...]
        │
        ▼
Commons/Settings.qml  getBarWidgetsForScreen(screenName)        :1014-1020
        │              (per-screen override if enabled, else data.bar.widgets)
        ▼
Modules/Bar/Bar.qml
        barWidgets   :82   ← Settings.getBarWidgetsForScreen(screen.name)
        ListModels   :85-87  leftWidgetsModel / centerWidgetsModel / rightWidgetsModel
        syncWidgetModel():96-129   rebuilds ONLY when IDs/order change
        Connections  :134-141  ← BarService.widgetsRevisionChanged
        │
        ▼
horizontalBarComponent :626-750   (or verticalBarComponent :505-623)
        3× RowLayout (Left :667 / Center :695 / Right :722)
        Repeater { model: leftWidgetsModel
          delegate: BarWidgetLoader   :678, :705, :733  (vertical: :555, :580, :606)
            widgetId / widgetScreen / widgetProps
        }
        │
        ▼
Modules/Bar/Extras/BarWidgetLoader.qml
        checkWidgetExists() :50-52  → BarWidgetRegistry.hasWidget()
        loader.setSource(Quickshell.shellDir + "/Modules/Bar/Widgets/" + widgetId + ".qml")  :71-84
        onLoaded: fill cross-axis :114-125, apply props :127-132,
                  BarService.registerWidget(...) :134-142, call item.onLoaded() :144-147
        │
        ▼
Modules/Bar/Widgets/<Name>.qml   (the widget itself)
```

### 3.1 Ordering, position and visibility

All three live in **settings, not code**. Each entry in
`bar.widgets.{left,center,right}` is `{ "id": "<WidgetId>", ...settings }`:

- **zone** = which array it's in (`left` / `center` / `right`)
- **visibility** = whether it appears at all
- **order** = index within the array
- **settings** = the remaining keys on the object (§4)

Defaults (`Assets/settings-default.json`):

```json
"left":   [ {"id":"Launcher"}, {"id":"Clock"}, {"id":"SystemMonitor"},
            {"id":"ActiveWindow"}, {"id":"MediaMini"} ],
"center": [ {"id":"Workspace"} ],
"right":  [ {"id":"Tray"}, {"id":"NotificationHistory"}, {"id":"Battery"},
            {"id":"Volume"}, {"id":"Brightness"}, {"id":"Dashboard"} ]
```

Per-screen layouts are supported: `getBarWidgetsForScreen()`
(`Commons/Settings.qml:1014-1020`) returns the screen override's `widgets`
when one is enabled, otherwise the global `data.bar.widgets`.

### 3.2 Why loading is by path

`BarWidgetLoader` deliberately does **not** use
`BarWidgetRegistry.getWidget(id).url`:

```qml
// Modules/Bar/Extras/BarWidgetLoader.qml:80-83
// Load by file path, not via BarWidgetRegistry.getWidget().url: registry
// entries are inline Component {} declarations, so their .url resolves to
// BarWidgetRegistry.qml itself (a singleton), not the widget file.
loader.setSource(_barWidgetsDir + root.widgetId + ".qml", props);
```

Consequences:

- The file name must equal the widget ID.
- The loader still gates on `BarWidgetRegistry.hasWidget()` (`:74-76`), so an
  unregistered file is never loaded, and logs a warning at startup if the ID
  is unknown (`:156-160`).
- Initial properties are passed via `setSource()` so they exist during
  `Component.onCompleted` — important for widgets that build
  `BarService` registration keys from `screen.name`/`section`/index (`:54-69`).

### 3.3 Model sync without tearing down widgets

`syncWidgetModel()` (`Modules/Bar/Bar.qml:96-129`) compares the model's
current IDs against the new list and calls `model.clear()` **only when the
structure (IDs or order) changed**. If only a widget's *settings* changed, the
model is untouched and delegates keep reading fresh settings — no reload, no
flash.

Structure changes are announced by `BarService.widgetsRevision`
(`Services/UI/BarService.qml:26`), which the settings UI bumps after any
add/remove/reorder/move (`Modules/Panels/Settings/Tabs/Bar/BarTab.qml:29-43`,
`:45-57`, `:59-69`, `:77-90`). Deliberately **not** bumped by
`_updateWidgetSettingsInSection` (`BarTab.qml:71-75`) — a settings-only change
doesn't alter structure, so delegates must keep their existing instances and
read fresh values (comment at `:70-71`). `Bar.qml:134-141` listens with a
`Connections` block — not `onBarWidgetsChanged`, because
`getBarWidgetsForScreen()` returns the same object reference even when
contents change, so a property binding would never fire (comment at
`:130-133`). External file reloads bump it too (`BarService.qml:168-175`).

There is also a teardown guard: `Bar.qml:89-90` sets `_destroyed` so deferred
`Qt.callLater` callbacks can't run during destruction (avoids SIGSEGV with
async widget incubation).

### 3.4 Filtering

Before a model is built, entries whose ID fails `BarWidgetRegistry.hasWidget`
are dropped by `filterValidWidgets()` (`Modules/Bar/Bar.qml:24-31`), and again
inside `syncWidgetModel()`. This keeps stale/broken settings entries from
rendering.

### 3.5 Bar instantiation

- The bar window is created per screen in
  `Modules/MainScreen/BarContentWindow.qml:222-225` (`Bar { anchors.fill: parent }`).
- Which screens get a bar is gated by `Settings.data.bar.monitors`:
  `Bar.qml:187-198` activates content when the list is **empty** (meaning all
  monitors) or includes the screen name.
- `Bar.qml:496-500` picks `verticalBarComponent` (`:505`) vs
  `horizontalBarComponent` (`:626`) from the per-screen `barPosition`
  (`left`/`right` = vertical; `top`/`bottom` = horizontal). Vertical maps the
  three zones to top/center/bottom.

---

## 4. Settings integration

### 4.1 Storage shape

| Level | Key | Meaning |
|---|---|---|
| Layout | `data.bar.widgets.{left,center,right}[]` | array of `{id, ...settings}` — zone, order, visibility, settings |
| Per-screen layout | screen override `widgets` | same shape; wins when `override.enabled !== false` |
| Bar chrome | `data.bar.barType`, `data.bar.contentPadding`, `data.bar.widgetSpacing` … | not per-widget |
| Defaults schema | `BarWidgetRegistry.widgetMetadata` | default value per widget per setting |

### 4.2 Migration is registry-driven

`upgradeSettings()` (`Commons/Settings.qml:1277-1354`) runs on load and:

1. **Prunes unknown widgets** — any entry failing
   `BarWidgetRegistry.hasWidget(widget.id)` is spliced out with a warning
   (`Commons/Settings.qml:1296`). *So: register a widget before adding it to
   anyone's layout, or their entry gets deleted on next load.*
2. Calls `upgradeWidget()` per entry (`:1349`, defined at `:1358-1389`), which
   - **deletes** any key not present in `widgetMetadata` (deprecated settings), and
   - **injects** missing keys with the metadata default.

The whole migration is deferred until the singleton is populated
(`:1279-1283` retries via `Qt.callLater`).

### 4.3 The settings UI

| Piece | Path | Role |
|---|---|---|
| Bar tab | `Modules/Panels/Settings/Tabs/Bar/BarTab.qml` | mutation helpers: `_addWidgetToSection` `:29`, `_removeWidgetFromSection` `:45`, `_reorderWidgetInSection` `:59`, `_updateWidgetSettingsInSection` `:73`, `_moveWidgetBetweenSections` `:77`; available list built from `getAvailableWidgets()` `:130-139` |
| Layout editor | `Modules/Panels/Settings/Tabs/Bar/WidgetsSubTab.qml` | three `NSectionEditor`s for left/center/right, drag-and-drop reorder |
| Monitor overrides | `Modules/Panels/Settings/Tabs/Bar/MonitorsSubTab.qml` | per-screen layout |
| Dialog | `Modules/Panels/Settings/Bar/BarWidgetSettingsDialog.qml` | resolves the per-widget panel via `widgetSettingsMap` |
| Per-widget panels | `Modules/Panels/Settings/Bar/WidgetSettings/<Id>Settings.qml` | 30 panels, one per widget |

### 4.4 When a widget has no settings

Omit the `widgetMetadata` entry and the `widgetSettingsMap` entry. Then
`widgetHasUserSettings(id)` (`BarWidgetRegistry.qml:463-465`) returns false
and no "Widget settings" context item is offered.

---

## 5. Interactivity

### Clicks, tooltips, context menus

```qml
// Modules/Bar/Widgets/NightLight.qml:48-64 — toggle on left click
onClicked: { ... }

// :66-85 — right-click context menu with the standard settings action
NPopupContextMenu {
  id: contextMenu
  model: [{ "label": "Widget settings", "action": "widget-settings", "icon": "settings" }]
  onTriggered: action => {
    contextMenu.close();
    PanelService.closeContextMenu(screen);
    if (action === "widget-settings")
      BarService.openWidgetSettings(screen, section, sectionWidgetIndex, widgetId, widgetSettings);
  }
}
onRightClicked: PanelService.showContextMenu(contextMenu, root, screen);
```

Common services widgets use:

- **`PanelService`** — `getPanel("<name>", screen)?.toggle(...)` / `?.open(...)`
  to open panels (calendar, launcher, dashboard…), `showContextMenu(...)`.
- **`TooltipService.show/hide/updateText`** + `BarService.getTooltipDirection(screen?.name)`
  (`BarService.qml:494`) for tooltips.
- **`HoverPanelService.arm/disarm`** to open a panel on hover instead of a
  tooltip (`hoverOpensPanel`).
- **`BarService.openWidgetSettings(...)`** (`BarService.qml:530-604`) — opens
  `BarWidgetSettingsDialog`, writes the result back into
  `Settings.data.bar.widgets[...]`, then bumps `widgetsRevision`.

### Instance registry

`BarWidgetLoader.onLoaded` registers every instance with
`BarService.registerWidget(screen, section, widgetId, index, item)`
(`BarService.qml:286`), keyed `"screen|section|widgetId|index"`, and
unregisters on destroy (`BarWidgetLoader.qml:24-29`, `:101-106`, `:150-152`).

External lookup API on `BarService`:

- `lookupWidget(widgetId, screen?, section?, index?)` — `BarService.qml:310`
- `getAllWidgetInstances(widgetId?, screen?, section?)` — `:345`
- `getWidgetWithMetadata(widgetId, screen?, section?)` — `:370`
- `getWidgetsBySection(section, screen?)` — `:387` (used by hot corners)
- `getAllRegisteredWidgets()` — `:413`
- `hasWidget(widgetId, section?, screen?)` — `:431`
- `getTooltipDirection(screenName)` — `:494`
- `openWidgetSettings(...)` — `:530`

### IPC

Bar-level commands live in `Services/Control/IPCService.qml` under
`IpcHandler { target: "bar" }` — `IPCService.qml:48-83` — `toggle`, `hideBar`,
`showBar`, `peek`, `setDisplayMode(mode, screen)`, `setPosition(position, screen)`
(see `IPC.md`, "bar" section).

`CustomButton` widgets additionally register per-instance IPC identifiers
through `Services/Control/CustomButtonIPCService.qml` (`target: "cb"`), driven
by their `ipcIdentifier` setting.

> Per AGENTS.md: whenever you add/remove/rename an IPC handler or change its
> args, update the matching table in `IPC.md`.

---

## 6. Component inventory

### `Modules/Bar/`

```
Modules/Bar/
├── Bar.qml                     Layout: zones, models, sync, hot corners, orientation
├── Extras/
│   ├── BarExclusionZone.qml    Layer-shell exclusion window (reserves screen space)
│   ├── BarWidgetLoader.qml     Loads a widget by ID, sizes it, registers it
│   ├── BarPill.qml             Orientation-agnostic pill wrapper
│   ├── BarPillHorizontal.qml   Horizontal capsule + hover-expand
│   ├── BarPillVertical.qml     Vertical capsule variant
│   ├── TrayMenu.qml            PopupWindow for tray item menus
│   └── WorkspacePill.qml       Per-workspace pill used by the Workspace widget
└── Widgets/                    30 widget files, one widget each
    ActiveWindow, AudioVisualizer, Battery, Bluetooth, Brightness, Clock,
    CustomButton, DarkMode, Dashboard, KeepAwake, KeyboardLayout, Launcher,
    LockKeys, MediaMini, Microphone, Network, NightLight, NotificationHistory,
    Pomodoro, PowerProfile, SessionMenu, Settings, Spacer, SystemMonitor, Taskbar,
    Tray, Volume, VPN, WallpaperSelector, Workspace
```

### Shared widget building blocks

| Component | Path | Purpose |
|---|---|---|
| `BarWidgetLoader` | `Modules/Bar/Extras/BarWidgetLoader.qml:6-11` | contract: `required widgetId`, `widgetScreen`, `widgetProps` |
| `NIconButton` | `Widgets/NIconButton.qml:10-43` | square icon button base |
| `BarPill` | `Modules/Bar/Extras/BarPill.qml:6-34` | capsule base |
| `NPopupContextMenu` | `Widgets/NPopupContextMenu.qml` | right-click menus |
| `TooltipService` / `HoverPanelService` / `PanelService` | `Services/UI/` | tooltips, hover-open, panels |
| `BarService` | `Services/UI/BarService.qml` | instance registry, revision, widget-settings dialog |
| `BarWidgetRegistry` | `Services/UI/BarWidgetRegistry.qml` | existence + defaults |

---

## 7. Naming conventions

1. **Widget IDs are PascalCase** and equal the file name (`Clock`,
   `NotificationHistory`).
2. **Section IDs are lowercase**: `left`, `center`, `right`.
3. **Settings keys are camelCase** (`formatHorizontal`,
   `hideWhenZeroUnread`).
4. **Color-valued settings use the string `"none"` as "default/unset"**, and
   are applied via `Color.resolveColorKey(key)`.
5. **Settings-dialog paths are relative** to
   `Modules/Panels/Settings/Bar/` (`"WidgetSettings/ClockSettings.qml"`).
6. **Settings-panel files are `<Id>Settings.qml`.**
7. **Registry maps must all be updated together** — missing one of
   `widgets` / `widgetMetadata` / `widgetSettingsMap` produces a broken or
   settings-less widget, not a load error.

---

## 8. Known gotchas & historical notes

- **Plugin system was removed.** `BarService.destroyPluginWidgetInstances`
  (`BarService.qml:449-472`) and the `plugin:` ID prefix are leftovers;
  `Commons/Settings.qml:1251-1255` documents the removal.
  `BarWidgetLoader` only loads from `Modules/Bar/Widgets/`. `BarTab.createBadges`
  has a dead `isPlugin` parameter. Don't design around plugins — there is no
  loader for them.
- **Register before you add to a layout.** Unregistered IDs are pruned from
  user settings on load (`Commons/Settings.qml:1296`).
- **`widgetSettingBounds` must not be folded into `widgetMetadata`** — see the
  rationale comment at `BarWidgetRegistry.qml:45-50`.
- **Async loading:** the Loader is `asynchronous: true`
  (`BarWidgetLoader.qml:89`); widgets can appear a frame or two after the bar.
- **CPU-heavy widgets** are flagged in `cpuIntensiveWidgets`
  (`BarWidgetRegistry.qml:467`) — currently only `AudioVisualizer`.
- **EGL note:** if the shell renders blank in the devshell, see the
  `__EGL_VENDOR_LIBRARY_FILENAMES` note in `../AGENTS.md`.
