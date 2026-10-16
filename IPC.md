# Mordial IPC Commands

The shell exposes commands over Quickshell's IPC interface. Call them with:

```bash
qs ipc call <target> <function> [args...]
```

List everything registered at runtime with `qs ipc show`, or `qs ipc call <target> --help`.

Handlers are defined in:

- `Services/Control/IPCService.qml` — all standard targets
- `Services/Control/CustomButtonIPCService.qml` — the `cb` target for `CustomButton` bar widgets
- `Services/Control/PomodoroIPCService.qml` — the `pomodoro` target for `Pomodoro` desktop widgets

> **Keep this file in sync.** When you add, remove, or rename an `IpcHandler` function, update the table below.

---

## Core UI & Shell

| Target           | Function         | Args                 | Description                                                                           |
| ---------------- | ---------------- | -------------------- | ------------------------------------------------------------------------------------- |
| `bar`            | `toggle`         | —                    | Toggle bar visibility                                                                 |
| `bar`            | `hideBar`        | —                    | Hide the bar                                                                          |
| `bar`            | `showBar`        | —                    | Show the bar                                                                          |
| `bar`            | `peek`           | —                    | Peek the bar (temporary reveal)                                                       |
| `bar`            | `setDisplayMode` | `mode`, `screen`     | Set display mode: `always_visible`, `non_exclusive`, `auto_hide`                      |
| `bar`            | `setPosition`    | `position`, `screen` | Set bar edge: `top`, `bottom`, `left`, `right`                                        |
| `settings`       | `toggle`         | —                    | Toggle the settings panel                                                             |
| `settings`       | `toggleTab`      | `tab`                | Toggle settings on a tab (`tab` or `tab/subtab`)                                      |
| `settings`       | `open`           | —                    | Open the settings panel                                                               |
| `settings`       | `openTab`        | `tab`                | Open settings on a tab (`tab` or `tab/subtab`)                                        |
| `calendar`       | `toggle`         | —                    | Toggle the calendar/clock panel                                                       |
| `launcher`       | `toggle`         | —                    | Toggle launcher (app mode)                                                            |
| `launcher`       | `clipboard`      | —                    | Toggle launcher in clipboard mode                                                     |
| `launcher`       | `command`        | —                    | Toggle launcher in command mode                                                       |
| `launcher`       | `emoji`          | —                    | Toggle launcher in emoji mode                                                         |
| `launcher`       | `windows`        | —                    | Toggle launcher in windows mode                                                       |
| `launcher`       | `settings`       | —                    | Toggle launcher in settings-search mode                                               |
| `switcher`       | `next`           | —                    | Open the window switcher, or cycle selection forward                                  |
| `switcher`       | `previous`       | —                    | Open the window switcher, or cycle selection backward                                 |
| `switcher`       | `commit`         | —                    | Focus the selected window and close the switcher                                      |
| `switcher`       | `cancel`         | —                    | Close the switcher without changing focus                                             |
| `dashboard`      | `toggle`         | —                    | Toggle the dashboard panel                                                            |
| `controlCenter`  | `toggle`         | —                    | Legacy alias of `dashboard toggle`                                                    |
| `dock`           | `toggle`         | —                    | Toggle the dock                                                                       |
| `desktopWidgets` | `toggle`         | —                    | Toggle desktop widgets                                                                |
| `desktopWidgets` | `enable`         | —                    | Enable desktop widgets                                                                |
| `desktopWidgets` | `disable`        | —                    | Disable desktop widgets                                                               |
| `desktopWidgets` | `edit`           | —                    | Toggle desktop widget edit mode                                                       |
| `sessionMenu`    | `toggle`         | —                    | Toggle the session menu                                                               |
| `sessionMenu`    | `lock`           | —                    | Lock the screen                                                                       |
| `sessionMenu`    | `lockAndSuspend` | —                    | Lock the screen and suspend                                                           |
| `lockScreen`     | `lock`           | —                    | Lock the screen (no-op if already locked)                                             |
| `toast`          | `send`           | `json`               | Show a toast (`{title, body, icon, type, duration}`; type `notice`/`warning`/`error`) |
| `toast`          | `dismiss`        | —                    | Dismiss the current toast                                                             |
| `systemMonitor`  | `toggle`         | —                    | Toggle the system monitor panel                                                       |

### Settings tab names

`settings toggleTab` / `openTab` accept a tab name, optionally with a subtab index `tab/subtab`:

`about`, `audio`, `bar`, `colorscheme`, `lockscreen`, `dashboard` (alias `controlcenter`), `desktopwidgets`, `osd`, `display`, `dock`, `general`, `hooks`, `launcher`, `location`, `connections`, `notifications`, `plugins`, `sessionmenu`, `system` (alias `systemmonitor`), `userinterface`, `wallpaper`, `idle`.

---

## Notifications

| Target          | Function                  | Args             | Description                                        |
| --------------- | ------------------------- | ---------------- | -------------------------------------------------- |
| `notifications` | `toggleHistory`           | —                | Toggle the notification history panel              |
| `notifications` | `toggleDND`               | —                | Toggle Do Not Disturb                              |
| `notifications` | `enableDND`               | —                | Enable Do Not Disturb                              |
| `notifications` | `disableDND`              | —                | Disable Do Not Disturb                             |
| `notifications` | `clear`                   | —                | Clear notification history                         |
| `notifications` | `dismissOldest`           | —                | Dismiss the oldest popup                           |
| `notifications` | `removeOldestHistory`     | —                | Remove the oldest history entry                    |
| `notifications` | `dismissAll`              | —                | Dismiss all popups                                 |
| `notifications` | `getHistory`              | —                | Return history as JSON                             |
| `notifications` | `removeFromHistory`       | `id`             | Remove a history entry by id                       |
| `notifications` | `invokeDefault`           | `index`          | Invoke the default action of popup at `index`      |
| `notifications` | `invokeDefaultAndDismiss` | `index`          | Invoke default action and dismiss popup at `index` |
| `notifications` | `invokeAction`            | `id`, `actionId` | Invoke a specific action on a notification         |
| `notifications` | `getActions`              | `index`          | Return the actions of popup at `index` as JSON     |

---

## Hardware & Networking

| Target         | Function             | Args    | Description                           |
| -------------- | -------------------- | ------- | ------------------------------------- |
| `brightness`   | `increase`           | —       | Increase brightness                   |
| `brightness`   | `decrease`           | —       | Decrease brightness                   |
| `brightness`   | `set`                | `value` | Set brightness (`0-100` or `0.0-1.0`) |
| `monitors`     | `on`                 | —       | Turn monitors on                      |
| `monitors`     | `off`                | —       | Turn monitors off                     |
| `volume`       | `increase`           | —       | Increase output volume                |
| `volume`       | `decrease`           | —       | Decrease output volume                |
| `volume`       | `muteOutput`         | —       | Toggle output mute                    |
| `volume`       | `increaseInput`      | —       | Increase input volume                 |
| `volume`       | `decreaseInput`      | —       | Decrease input volume                 |
| `volume`       | `muteInput`          | —       | Toggle input mute                     |
| `volume`       | `togglePanel`        | —       | Toggle the audio panel                |
| `volume`       | `openPanel`          | —       | Open the audio panel                  |
| `volume`       | `closePanel`         | —       | Close the audio panel                 |
| `wifi`         | `toggle`             | —       | Toggle Wi-Fi                          |
| `wifi`         | `enable`             | —       | Enable Wi-Fi                          |
| `wifi`         | `disable`            | —       | Disable Wi-Fi                         |
| `network`      | `togglePanel`        | —       | Toggle the network panel              |
| `bluetooth`    | `toggle`             | —       | Toggle Bluetooth                      |
| `bluetooth`    | `enable`             | —       | Enable Bluetooth                      |
| `bluetooth`    | `disable`            | —       | Disable Bluetooth                     |
| `bluetooth`    | `togglePanel`        | —       | Toggle the Bluetooth panel            |
| `bluetooth`    | `toggleAutoConnect`  | —       | Toggle Bluetooth auto-connect         |
| `bluetooth`    | `enableAutoConnect`  | —       | Enable Bluetooth auto-connect         |
| `bluetooth`    | `disableAutoConnect` | —       | Disable Bluetooth auto-connect        |
| `airplaneMode` | `toggle`             | —       | Toggle airplane mode                  |
| `airplaneMode` | `enable`             | —       | Enable airplane mode                  |
| `airplaneMode` | `disable`            | —       | Disable airplane mode                 |
| `battery`      | `togglePanel`        | —       | Toggle the battery panel              |

---

## Media, Power & Theming

| Target          | Function              | Args             | Description                                          |
| --------------- | --------------------- | ---------------- | ---------------------------------------------------- |
| `media`         | `toggle`              | —                | Toggle the media mini panel                          |
| `media`         | `playPause`           | —                | Play/pause                                           |
| `media`         | `play`                | —                | Play                                                 |
| `media`         | `stop`                | —                | Stop                                                 |
| `media`         | `pause`               | —                | Pause                                                |
| `media`         | `next`                | —                | Next track                                           |
| `media`         | `previous`            | —                | Previous track                                       |
| `media`         | `seekRelative`        | `offset`         | Seek by offset (seconds)                             |
| `media`         | `seekByRatio`         | `position`       | Seek to a ratio (`0.0-1.0`)                          |
| `powerProfile`  | `cycle`               | —                | Cycle power profile forward                          |
| `powerProfile`  | `cycleReverse`        | —                | Cycle power profile backward                         |
| `powerProfile`  | `set`                 | `mode`           | Set profile: `performance`, `balanced`, `powersaver` |
| `darkMode`      | `toggle`              | —                | Toggle dark mode                                     |
| `darkMode`      | `setDark`             | —                | Enable dark mode                                     |
| `darkMode`      | `setLight`            | —                | Disable dark mode                                    |
| `nightLight`    | `toggle`              | —                | Toggle night light (requires `wlsunset`)             |
| `colorScheme`   | `set`                 | `schemeName`     | Apply a predefined color scheme                      |
| `colorScheme`   | `setGenerationMethod` | `method`         | Set MD3 generation method                            |
| `wallpaper`     | `toggle`              | —                | Open the wallpaper picker (dashboard page)           |
| `wallpaper`     | `random`              | `screen`         | Set a random wallpaper (screen name or `all`/empty)  |
| `wallpaper`     | `get`                 | `screen`         | Return the current wallpaper path(s)                 |
| `wallpaper`     | `set`                 | `path`, `screen` | Set a specific wallpaper                             |
| `wallpaper`     | `refresh`             | —                | Refresh the wallpaper list                           |
| `wallpaper`     | `toggleAutomation`    | —                | Toggle wallpaper automation                          |
| `wallpaper`     | `enableAutomation`    | —                | Enable wallpaper automation                          |
| `wallpaper`     | `disableAutomation`   | —                | Disable wallpaper automation                         |
| `idleInhibitor` | `toggle`              | —                | Toggle idle inhibitor                                |
| `idleInhibitor` | `enable`              | —                | Enable idle inhibitor                                |
| `idleInhibitor` | `disable`             | —                | Disable idle inhibitor                               |
| `idleInhibitor` | `enableFor`           | `seconds`        | Enable idle inhibitor for N seconds                  |

---

## System & State

| Target     | Function | Args   | Description                                 |
| ---------- | -------- | ------ | ------------------------------------------- |
| `location` | `get`    | —      | Return the configured location name         |
| `location` | `set`    | `name` | Set the location name and refresh           |
| `state`    | `all`    | —      | Return all settings and shell state as JSON |

---

## Pomodoro

Controls the live `Pomodoro` desktop widget. Commands apply to every loaded instance so multi-monitor widgets stay in sync; `status` reports the first registered instance.

| Target     | Function    | Args   | Description                                        |
| ---------- | ----------- | ------ | -------------------------------------------------- |
| `pomodoro` | `start`     | —      | Start or resume the timer                          |
| `pomodoro` | `pause`     | —      | Pause the timer                                    |
| `pomodoro` | `toggle`    | —      | Toggle start/pause based on current state          |
| `pomodoro` | `reset`     | —      | Reset the current session's timer                  |
| `pomodoro` | `resetAll`  | —      | Reset everything, including the session count      |
| `pomodoro` | `skip`      | —      | Skip to the next phase                             |
| `pomodoro` | `stopAlarm` | —      | Stop the alarm sound if it is playing              |
| `pomodoro` | `setMode`   | `mode` | Switch phase: `work`, `short`, `long`, `0`, `1`, `2` |
| `pomodoro` | `status`    | —      | Return the first widget's state as JSON            |

> Requires at least one loaded `Pomodoro` widget; `status` returns `{"available": false}` otherwise.

---

## Custom Buttons (`cb`)

Controls `CustomButton` bar widgets by their user-defined `ipcIdentifier`. If the live widget is not loaded, the handler falls back to the configured commands in settings.

| Function  | Args         | Description                                         |
| --------- | ------------ | --------------------------------------------------- |
| `left`    | `identifier` | Trigger left click                                  |
| `right`   | `identifier` | Trigger right click                                 |
| `middle`  | `identifier` | Trigger middle click                                |
| `up`      | `identifier` | Trigger wheel up (separate wheel mode)              |
| `down`    | `identifier` | Trigger wheel down (separate wheel mode)            |
| `wheel`   | `identifier` | Trigger unified wheel action                        |
| `refresh` | `identifier` | Re-run the button's text command (live widget only) |

> `refresh` requires a loaded widget instance because it re-runs the in-memory command.
