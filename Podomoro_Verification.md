# Bar widget interaction

(Confirmed, Works) Icon appears in the bar (left section, next to Workspace).
(Confirmed, Works) Hovering the pill expands it to show the countdown (25:00 idle).
(Confirmed, Works) Left-click starts the timer; text counts down each second.
(Confirmed, Works) Left-click again pauses; text stays but stops counting.
(Confirmed, Works) Right-click opens the context menu; each item closes the menu and performs its action (Start/Pause, Skip, Reset session, Reset all, Stop alarm, Work/Short/Long mode).
(Confirmed, Works) “Widget settings” menu item opens the settings dialog.

# Settings dialog (PomodoroSettings.qml)

(Confirmed, Works) Inputs look like the shell (same styling as e.g. Workspace widget settings), not raw Qt controls.
(Confirmed, Works) Work/Short/Long/Sessions use the shell stepper (NSpinBox), not a boxed Qt SpinBox.
(Confirmed, Works) Alarm volume is a slider showing a % value.
(Confirmed, Works) Toggling Auto-start breaks, Auto-start work, Play sound, Repeat alarm visibly flips the switch and stays flipped after closing/reopening the dialog.
(Confirmed, Works) Toggling Play sound off hides the Repeat/Volume/Custom-path rows; on shows them.
(Confirmed, Works) Changing a number or the slider persists after closing/reopening.
(Not tested) Custom alarm sound field accepts a path and persists.
(Confirmed, Works) Icon/text color choices actually recolor the bar icon/text.

# Cross-cutting

qs ipc call pomodoro status returns sensible JSON (available: true, running, mode, remainingSeconds).

It only print out

```
{
  "available": false
}
```

(?) qs ipc call pomodoro setMode short then status switches mode and the bar icon/text update.

- Print out `  INFO qml: [20261019-211210] PomodoroIPCSer Set pomodoro mode to short`

(True) No new Pomodoro-related errors/warnings in the shell log after interacting.

# Extra:

There should be better interaction for the podomoro pause / start
