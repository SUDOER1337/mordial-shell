pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons

// File: Services/Control/PomodoroIPCService.qml
// Purpose: Registry of live DesktopPomodoro widget instances plus the
//          `pomodoro` IpcHandler target. The pomodoro timer state lives
//          inside the widget, so this service lets widgets register
//          themselves and exposes commands that apply to every instance.
// Functions:
//   init()                     - Force singleton instantiation (registers IpcHandler)
//   registerPomodoro(widget)   - Register a live pomodoro widget
//   unregisterPomodoro(widget) - Remove a destroyed pomodoro widget
//
// Helpers:
//   _keyFor(widget)  - Build a stable "screen:index" registry key
//   _allPomodoros()  - Collect every live pomodoro instance
//   _forEach(m, a)   - Invoke a named method on every live instance
//   _resolveMode(m)  - Map an IPC mode argument to a mode constant
//
// IPC Handler:
//   target "pomodoro" - start/pause/toggle/reset/resetAll/skip/stopAlarm/setMode/status
Singleton {
  id: root

  // Registry of live pomodoro widget instances, keyed by "screen:index".
  property var pomodoroRegistry: ({})

  /** Force singleton instantiation at startup, which registers the IpcHandler.
  */
  function init() {
    Logger.i("PomodoroIPCService", "Service started");
  }

  /** Build a stable registry key for a pomodoro widget instance.
  *  @param widget - DesktopPomodoro instance
  *  @returns The key "screenName:widgetIndex"
  */
  function _keyFor(widget) {
    var screenName = widget.screen && widget.screen.name ? widget.screen.name : "unknown";
    return screenName + ":" + widget.widgetIndex;
  }

  /** Register a live pomodoro widget so IPC commands can reach it.
  *  @param widget - DesktopPomodoro instance
  *  @returns true on success, false when widget is null
  */
  function registerPomodoro(widget) {
    if (!widget) {
      return false;
    }
    var key = _keyFor(widget);
    pomodoroRegistry[key] = widget;
    Logger.d("PomodoroIPCService", "Registered pomodoro widget:", key);
    return true;
  }

  /** Unregister a pomodoro widget when it is destroyed.
  *  @param widget - DesktopPomodoro instance
  *  @returns true if the instance was removed
  */
  function unregisterPomodoro(widget) {
    if (!widget) {
      return false;
    }
    var key = _keyFor(widget);
    if (pomodoroRegistry[key] === widget) {
      delete pomodoroRegistry[key];
      Logger.d("PomodoroIPCService", "Unregistered pomodoro widget:", key);
      return true;
    }
    return false;
  }

  /** Collect every live pomodoro instance.
  *  @returns Array of DesktopPomodoro instances
  */
  function _allPomodoros() {
    var list = [];
    for (var key in pomodoroRegistry) {
      var widget = pomodoroRegistry[key];
      if (widget) {
        list.push(widget);
      }
    }
    return list;
  }

  /** Invoke a named method on every live pomodoro instance.
  *  @param methodName - Name of the method to call on each widget
  *  @param args - Array of arguments to pass (defaults to none)
  *  @returns Number of instances the method was invoked on
  */
  function _forEach(methodName, args) {
    var list = _allPomodoros();
    var callArgs = args || [];
    for (var i = 0; i < list.length; i++) {
      var fn = list[i][methodName];
      if (typeof fn === "function") {
        fn.apply(list[i], callArgs);
      }
    }
    return list.length;
  }

  /** Map an IPC mode argument to the widget's mode constant.
  *  @param mode - String or numeric mode identifier
  *  @returns Mode int (0 work, 1 short break, 2 long break) or -1 when invalid
  */
  function _resolveMode(mode) {
    var key = String(mode).toLowerCase();
    if (key === "work" || key === "0")
      return 0;
    if (key === "short" || key === "shortbreak" || key === "short-break" || key === "1")
      return 1;
    if (key === "long" || key === "longbreak" || key === "long-break" || key === "2")
      return 2;
    return -1;
  }

  // IpcHandler for pomodoro commands using the 'pomodoro' target.
  // Commands apply to every registered widget so multi-monitor widgets
  // stay in sync; status reports the first registered instance.
  IpcHandler {
    target: "pomodoro"

    // Start or resume the timer: pomodoro start
    function start() {
      var count = _forEach("pomodoroStart");
      Logger.i("PomodoroIPCService", "Started pomodoro on " + count + " widget(s)");
    }

    // Pause the timer: pomodoro pause
    function pause() {
      var count = _forEach("pomodoroPause");
      Logger.i("PomodoroIPCService", "Paused pomodoro on " + count + " widget(s)");
    }

    // Toggle start/pause based on current state: pomodoro toggle
    function toggle() {
      var list = _allPomodoros();
      for (var i = 0; i < list.length; i++) {
        if (list[i].pomodoroRunning) {
          list[i].pomodoroPause();
        } else {
          list[i].pomodoroStart();
        }
      }
      Logger.i("PomodoroIPCService", "Toggled pomodoro on " + list.length + " widget(s)");
    }

    // Reset the current session's timer, keeping the session count: pomodoro reset
    function reset() {
      _forEach("pomodoroResetSession");
      Logger.i("PomodoroIPCService", "Reset pomodoro session");
    }

    // Reset everything including the completed session count: pomodoro resetAll
    function resetAll() {
      _forEach("pomodoroResetAll");
      Logger.i("PomodoroIPCService", "Reset all pomodoro state");
    }

    // Skip to the next phase: pomodoro skip
    function skip() {
      _forEach("pomodoroSkip");
      Logger.i("PomodoroIPCService", "Skipped pomodoro phase");
    }

    // Stop the alarm sound if it is playing: pomodoro stopAlarm
    function stopAlarm() {
      _forEach("pomodoroStopAlarm");
      Logger.i("PomodoroIPCService", "Stopped pomodoro alarm");
    }

    // Switch phase: pomodoro setMode "work|short|long|0|1|2"
    function setMode(mode: string) {
      var value = _resolveMode(mode);
      if (value < 0) {
        Logger.w("PomodoroIPCService", "Invalid pomodoro mode: " + mode + ". Valid: work, short, long, 0, 1, 2");
        return;
      }
      _forEach("pomodoroSetMode", [value]);
      Logger.i("PomodoroIPCService", "Set pomodoro mode to " + mode);
    }

    // Report the state of the first live widget as JSON: pomodoro status
    function status(): string {
      var list = _allPomodoros();
      if (list.length === 0) {
        return JSON.stringify({
                                "available": false
                              }, null, 2);
      }
      var w = list[0];
      return JSON.stringify({
                              "available": true,
                              "running": w.pomodoroRunning,
                              "mode": w.pomodoroMode,
                              "modeName": w.getModeName(),
                              "remainingSeconds": w.pomodoroRemainingSeconds,
                              "totalSeconds": w.pomodoroTotalSeconds,
                              "completedSessions": w.pomodoroCompletedSessions
                            }, null, 2);
    }
  }
}
