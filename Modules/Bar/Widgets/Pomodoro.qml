import QtQuick
import QtQuick.Controls
import Quickshell
import qs.Commons
import qs.Modules.Bar.Extras
import qs.Services.Control
import qs.Services.System
import qs.Services.UI
import qs.Widgets

// File: Modules/Bar/Widgets/Pomodoro.qml
// Purpose: Compact bar indicator + controller for the Pomodoro timer. Runs its
//          own timer state machine and registers with PomodoroIPCService so
//          `qs ipc call pomodoro ...` reaches every loaded instance.
// Functions:
//   getDurationForMode(mode)  - Seconds configured for a mode constant
//   pomodoroStart(stopSound)  - Start/resume the current phase
//   pomodoroPause()           - Pause the current phase
//   pomodoroResetSession()    - Restart the current phase's countdown
//   pomodoroResetAll()        - Reset timer, mode and completed sessions
//   pomodoroSkip()            - Advance to the next phase without counting
//   pomodoroStopAlarm()       - Silence a ringing alarm
//   pomodoroSetMode(mode)     - Switch to work/short-break/long-break
//   pomodoroAdvanceToNextPhase() - Compute the next phase and its duration
//   pomodoroOnFinished()      - Phase-finished handler (sound, toast, auto-start)
//   toggleRunning()           - Left-click behaviour (start/pause/stop alarm)
//   formatTime(seconds, t)    - MM:SS or HH:MM:SS display string
//   getModeIcon()             - Tabler icon for the active mode
//   getModeName()             - Human label for the active mode
//   getDisplayText()          - Remaining time, or the phase duration when idle
//   getTooltipText()          - Mode/session tooltip line
//
// Helpers:
//   _resolveAlarmSoundPath()  - Pick custom sound path or bundled alarm
Item {
  id: root

  property ShellScreen screen

  // Widget properties passed from Bar.qml for per-instance settings
  property string widgetId: ""
  property string section: ""
  property int sectionWidgetIndex: -1
  property int sectionWidgetsCount: 0
  // Aliased so PomodoroIPCService can key this bar instance.
  property int widgetIndex: sectionWidgetIndex

  property var widgetMetadata: BarWidgetRegistry.widgetMetadata[widgetId] ?? {}
  // Explicit screenName property ensures reactive binding when screen changes
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

  readonly property int workDuration: widgetSettings.workDuration !== undefined ? widgetSettings.workDuration : (widgetMetadata.workDuration !== undefined ? widgetMetadata.workDuration : 25)
  readonly property int shortBreakDuration: widgetSettings.shortBreakDuration !== undefined ? widgetSettings.shortBreakDuration : (widgetMetadata.shortBreakDuration !== undefined ? widgetMetadata.shortBreakDuration : 5)
  readonly property int longBreakDuration: widgetSettings.longBreakDuration !== undefined ? widgetSettings.longBreakDuration : (widgetMetadata.longBreakDuration !== undefined ? widgetMetadata.longBreakDuration : 15)
  readonly property int sessionsBeforeLongBreak: widgetSettings.sessionsBeforeLongBreak !== undefined ? widgetSettings.sessionsBeforeLongBreak : (widgetMetadata.sessionsBeforeLongBreak !== undefined ? widgetMetadata.sessionsBeforeLongBreak : 4)
  readonly property bool autoStartBreaks: widgetSettings.autoStartBreaks !== undefined ? widgetSettings.autoStartBreaks : (widgetMetadata.autoStartBreaks !== undefined ? widgetMetadata.autoStartBreaks : false)
  readonly property bool autoStartWork: widgetSettings.autoStartWork !== undefined ? widgetSettings.autoStartWork : (widgetMetadata.autoStartWork !== undefined ? widgetMetadata.autoStartWork : false)
  readonly property bool playSound: widgetSettings.playSound !== undefined ? widgetSettings.playSound : (widgetMetadata.playSound !== undefined ? widgetMetadata.playSound : true)
  readonly property real soundVolume: widgetSettings.soundVolume !== undefined ? widgetSettings.soundVolume : (widgetMetadata.soundVolume !== undefined ? widgetMetadata.soundVolume : 0.3)
  readonly property bool soundRepeat: widgetSettings.soundRepeat !== undefined ? widgetSettings.soundRepeat : (widgetMetadata.soundRepeat !== undefined ? widgetMetadata.soundRepeat : true)
  readonly property string customSoundPath: widgetSettings.customSoundPath !== undefined ? widgetSettings.customSoundPath : (widgetMetadata.customSoundPath !== undefined ? widgetMetadata.customSoundPath : "")
  readonly property string iconColorKey: widgetSettings.iconColor !== undefined ? widgetSettings.iconColor : widgetMetadata.iconColor
  readonly property string textColorKey: widgetSettings.textColor !== undefined ? widgetSettings.textColor : widgetMetadata.textColor

  // --- SOUND ---
  readonly property string alarmSoundFile: Qt.resolvedUrl("../../../Assets/Sounds/pomodoro-alarm.mp3").toString().replace("file://", "")
  property string alarmSoundPath: _resolveAlarmSoundPath()

  onCustomSoundPathChanged: {
    alarmSoundPath = _resolveAlarmSoundPath();
  }

  readonly property int modeWork: 0
  readonly property int modeShortBreak: 1
  readonly property int modeLongBreak: 2

  property bool pomodoroRunning: false
  property int pomodoroMode: modeWork
  property int pomodoroRemainingSeconds: 0
  property int pomodoroTotalSeconds: 0
  property int pomodoroOriginalTotal: 0
  property int pomodoroCompletedSessions: 0
  property bool pomodoroSoundPlaying: false

  property int workDurationSeconds: workDuration * 60
  property int shortBreakDurationSeconds: shortBreakDuration * 60
  property int longBreakDurationSeconds: longBreakDuration * 60

  onWorkDurationChanged: workDurationSeconds = workDuration * 60
  onShortBreakDurationChanged: shortBreakDurationSeconds = shortBreakDuration * 60
  onLongBreakDurationChanged: longBreakDurationSeconds = longBreakDuration * 60

  // BarWidgetLoader sets explicit width/height; these drive the natural size.
  implicitWidth: pill.width
  implicitHeight: pill.height

  // Register with the IPC service so `qs ipc call pomodoro ...` can reach this
  // widget. A dedicated child object keeps the base widget's own lifecycle
  // handlers intact; the service targets every live instance.
  QtObject {
    id: ipcRegistration
    Component.onCompleted: PomodoroIPCService.registerPomodoro(root)
    Component.onDestruction: PomodoroIPCService.unregisterPomodoro(root)
  }

  Timer {
    id: updateTimer
    interval: 1000
    repeat: true
    running: root.pomodoroRunning
    triggeredOnStart: false

    onTriggered: {
      if (!root.pomodoroRunning)
        return;
      root.pomodoroRemainingSeconds = root.pomodoroRemainingSeconds - 1;
      if (root.pomodoroRemainingSeconds <= 0) {
        root.pomodoroOnFinished();
      }
    }
  }

  Timer {
    id: alarmLimitTimer
    interval: 5000
    repeat: false
    running: false

    onTriggered: root.pomodoroStopAlarm()
  }

  // === Timer state machine ===
  function getDurationForMode(mode) {
    if (mode === modeWork)
      return workDurationSeconds;
    if (mode === modeShortBreak)
      return shortBreakDurationSeconds;
    if (mode === modeLongBreak)
      return longBreakDurationSeconds;
    return workDurationSeconds;
  }

  function pomodoroStart(stopSound) {
    if (stopSound && pomodoroSoundPlaying) {
      root.pomodoroStopAlarm();
    }
    if (root.pomodoroRemainingSeconds <= 0) {
      root.pomodoroRemainingSeconds = getDurationForMode(root.pomodoroMode);
      root.pomodoroOriginalTotal = root.pomodoroRemainingSeconds;
    } else if (root.pomodoroOriginalTotal <= 0) {
      root.pomodoroOriginalTotal = root.pomodoroRemainingSeconds;
    }
    root.pomodoroTotalSeconds = root.pomodoroTotalSeconds > 0 ? root.pomodoroTotalSeconds : root.pomodoroOriginalTotal;
    root.pomodoroRunning = true;
  }

  function pomodoroPause() {
    root.pomodoroRunning = false;
    SoundService.stopSound(root.alarmSoundPath);
    root.pomodoroSoundPlaying = false;
    alarmLimitTimer.stop();
  }

  function pomodoroResetSession() {
    root.pomodoroRunning = false;
    root.pomodoroRemainingSeconds = getDurationForMode(root.pomodoroMode);
    root.pomodoroTotalSeconds = 0;
    root.pomodoroOriginalTotal = 0;
    SoundService.stopSound(root.alarmSoundPath);
    root.pomodoroSoundPlaying = false;
    alarmLimitTimer.stop();
  }

  function pomodoroResetAll() {
    root.pomodoroRunning = false;
    root.pomodoroRemainingSeconds = 0;
    root.pomodoroTotalSeconds = 0;
    root.pomodoroOriginalTotal = 0;
    root.pomodoroCompletedSessions = 0;
    root.pomodoroMode = modeWork;
    SoundService.stopSound(root.alarmSoundPath);
    root.pomodoroSoundPlaying = false;
    alarmLimitTimer.stop();
  }

  function pomodoroSkip() {
    root.pomodoroRunning = false;
    SoundService.stopSound(root.alarmSoundPath);
    root.pomodoroSoundPlaying = false;
    alarmLimitTimer.stop();
    pomodoroAdvanceToNextPhase();
  }

  function pomodoroStopAlarm() {
    if (root.pomodoroSoundPlaying) {
      SoundService.stopSound(root.alarmSoundPath);
      root.pomodoroSoundPlaying = false;
      alarmLimitTimer.stop();
    }
  }

  function pomodoroSetMode(mode) {
    if (root.pomodoroRunning) {
      root.pomodoroPause();
    }
    root.pomodoroMode = mode;
    root.pomodoroRemainingSeconds = getDurationForMode(mode);
    root.pomodoroTotalSeconds = 0;
    root.pomodoroOriginalTotal = 0;
  }

  function pomodoroAdvanceToNextPhase() {
    if (root.pomodoroMode === modeWork) {
      if (root.pomodoroCompletedSessions + 1 >= root.sessionsBeforeLongBreak) {
        root.pomodoroMode = modeLongBreak;
      } else {
        root.pomodoroMode = modeShortBreak;
      }
    } else {
      if (root.pomodoroMode === modeLongBreak) {
        root.pomodoroCompletedSessions = 0;
      } else {
        root.pomodoroCompletedSessions++;
      }
      root.pomodoroMode = modeWork;
    }
    root.pomodoroRemainingSeconds = getDurationForMode(root.pomodoroMode);
    root.pomodoroTotalSeconds = 0;
    root.pomodoroOriginalTotal = 0;
  }

  function pomodoroOnFinished() {
    root.pomodoroRunning = false;
    root.pomodoroRemainingSeconds = 0;
    root.pomodoroSoundPlaying = true;

    if (root.playSound !== false) {
      const repeat = root.soundRepeat;
      SoundService.playSound(root.alarmSoundPath, {
                               repeat: repeat,
                               volume: root.soundVolume
                             });
      if (repeat) {
        alarmLimitTimer.start();
      }
    }

    var toastMessage;
    var shouldAutoStart = false;

    if (root.pomodoroMode === modeWork) {
      toastMessage = "Work session complete! Time for a break.";
      shouldAutoStart = root.autoStartBreaks;
    } else if (root.pomodoroMode === modeLongBreak) {
      toastMessage = "Long break over! Ready for a new cycle?";
      shouldAutoStart = root.autoStartWork;
    } else {
      toastMessage = "Break over! Ready to focus?";
      shouldAutoStart = root.autoStartWork;
    }

    ToastService.showNotice("Pomodoro", toastMessage, "clock");

    pomodoroAdvanceToNextPhase();

    if (shouldAutoStart) {
      Qt.callLater(() => {
                     root.pomodoroStart(false);
                   });
    }
  }

  // === Display helpers ===
  function formatTime(seconds, totalTimeSeconds) {
    const hours = Math.floor(seconds / 3600);
    const minutes = Math.floor((seconds % 3600) / 60);
    const secs = seconds % 60;

    if (!totalTimeSeconds || totalTimeSeconds === 0) {
      if (hours > 0) {
        return hours.toString().padStart(2, '0') + ':' + minutes.toString().padStart(2, '0') + ':' + secs.toString().padStart(2, '0');
      }
      return minutes.toString().padStart(2, '0') + ':' + secs.toString().padStart(2, '0');
    }

    if (totalTimeSeconds < 3600) {
      return minutes.toString().padStart(2, '0') + ':' + secs.toString().padStart(2, '0');
    }
    return hours.toString().padStart(2, '0') + ':' + minutes.toString().padStart(2, '0') + ':' + secs.toString().padStart(2, '0');
  }

  function getModeIcon() {
    if (pomodoroMode === modeWork)
      return "brain";
    if (pomodoroMode === modeShortBreak)
      return "coffee";
    if (pomodoroMode === modeLongBreak)
      return "bed";
    return "clock";
  }

  function getModeName() {
    if (pomodoroMode === modeWork)
      return "Work";
    if (pomodoroMode === modeShortBreak)
      return "Short break";
    if (pomodoroMode === modeLongBreak)
      return "Long break";
    return "Pomodoro";
  }

  function getDisplayText() {
    var secs = pomodoroRemainingSeconds > 0 ? pomodoroRemainingSeconds : getDurationForMode(pomodoroMode);
    return formatTime(secs, 0);
  }

  function getTooltipText() {
    if (pomodoroSoundPlaying)
      return getModeName() + " - alarm ringing";
    var state = pomodoroRunning ? "" : (pomodoroRemainingSeconds > 0 ? " (paused)" : " (idle)");
    return getModeName() + state + " - Session " + (pomodoroCompletedSessions + 1) + "/" + sessionsBeforeLongBreak;
  }

  /** Left-click: silence a ringing alarm, otherwise toggle run/pause. */
  function toggleRunning() {
    if (pomodoroSoundPlaying) {
      pomodoroStopAlarm();
    } else if (pomodoroRunning) {
      pomodoroPause();
    } else {
      pomodoroStart(true);
    }
  }

  function _resolveAlarmSoundPath() {
    const custom = (customSoundPath || "").trim();
    return custom.length > 0 ? custom : alarmSoundFile;
  }

  // === Presentation ===
  BarPill {
    id: pill

    screen: root.screen
    oppositeDirection: BarService.getPillDirection(root)
    customIconColor: Color.resolveColorKeyOptional(root.iconColorKey)
    customTextColor: Color.resolveColorKeyOptional(root.textColorKey)
    icon: root.getModeIcon()
    text: root.getDisplayText()
    // Keep the countdown visible while a phase is active or paused with time
    // left; collapse to just the mode icon when fully idle.
    forceOpen: root.pomodoroRunning || root.pomodoroRemainingSeconds > 0 || root.pomodoroSoundPlaying
    tooltipText: root.getTooltipText()

    onClicked: root.toggleRunning()
    onRightClicked: PanelService.showContextMenu(contextMenu, pill, root.screen)
  }

  NPopupContextMenu {
    id: contextMenu

    model: [
      {
        "label": root.pomodoroRunning ? "Pause" : "Start",
        "action": "toggle",
        "icon": root.pomodoroRunning ? "player-pause" : "player-play"
      },
      {
        "label": "Skip phase",
        "action": "skip",
        "icon": "player-skip-forward"
      },
      {
        "label": "Reset session",
        "action": "reset-session",
        "icon": "refresh"
      },
      {
        "label": "Reset all",
        "action": "reset-all",
        "icon": "reload"
      },
      {
        "label": "Stop alarm",
        "action": "stop-alarm",
        "icon": "bell-off"
      },
      {
        "label": "Work mode",
        "action": "mode-work",
        "icon": "brain"
      },
      {
        "label": "Short break",
        "action": "mode-short",
        "icon": "coffee"
      },
      {
        "label": "Long break",
        "action": "mode-long",
        "icon": "bed"
      },
      {
        "label": "Widget settings",
        "action": "widget-settings",
        "icon": "settings"
      },
    ]

    onTriggered: action => {
                   contextMenu.close();
                   PanelService.closeContextMenu(root.screen);

                   if (action === "toggle") {
                     root.toggleRunning();
                   } else if (action === "skip") {
                     root.pomodoroSkip();
                   } else if (action === "reset-session") {
                     root.pomodoroResetSession();
                   } else if (action === "reset-all") {
                     root.pomodoroResetAll();
                   } else if (action === "stop-alarm") {
                     root.pomodoroStopAlarm();
                   } else if (action === "mode-work") {
                     root.pomodoroSetMode(root.modeWork);
                   } else if (action === "mode-short") {
                     root.pomodoroSetMode(root.modeShortBreak);
                   } else if (action === "mode-long") {
                     root.pomodoroSetMode(root.modeLongBreak);
                   } else if (action === "widget-settings") {
                     BarService.openWidgetSettings(root.screen, root.section, root.sectionWidgetIndex, root.widgetId, root.widgetSettings);
                   }
                 }
  }
}
