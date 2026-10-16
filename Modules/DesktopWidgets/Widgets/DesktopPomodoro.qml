import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Modules.DesktopWidgets
import qs.Services.Control
import qs.Services.System
import qs.Services.UI
import qs.Widgets

DraggableDesktopWidget {
  id: root

  // Register with the IPC service so `qs ipc call pomodoro ...` can reach this
  // widget. A dedicated child object is used so we don't override the base
  // widget's own Component.onCompleted (which initializes its scale).
  // The service targets every live instance, so no per-instance identifier is needed.
  QtObject {
    id: ipcRegistration
    Component.onCompleted: PomodoroIPCService.registerPomodoro(root)
    Component.onDestruction: PomodoroIPCService.unregisterPomodoro(root)
  }

  readonly property var widgetMetadata: DesktopWidgetRegistry.widgetMetadata["Pomodoro"]

  // Widget data properties
  readonly property bool compactMode: widgetData.compactMode !== undefined ? widgetData.compactMode : (widgetMetadata.compactMode !== undefined ? widgetMetadata.compactMode : false)
  readonly property int workDuration: widgetData.workDuration !== undefined ? widgetData.workDuration : (widgetMetadata.workDuration !== undefined ? widgetMetadata.workDuration : 25)
  readonly property int shortBreakDuration: widgetData.shortBreakDuration !== undefined ? widgetData.shortBreakDuration : (widgetMetadata.shortBreakDuration !== undefined ? widgetMetadata.shortBreakDuration : 5)
  readonly property int longBreakDuration: widgetData.longBreakDuration !== undefined ? widgetData.longBreakDuration : (widgetMetadata.longBreakDuration !== undefined ? widgetMetadata.longBreakDuration : 15)
  readonly property int sessionsBeforeLongBreak: widgetData.sessionsBeforeLongBreak !== undefined ? widgetData.sessionsBeforeLongBreak : (widgetMetadata.sessionsBeforeLongBreak !== undefined ? widgetMetadata.sessionsBeforeLongBreak : 4)
  readonly property bool autoStartBreaks: widgetData.autoStartBreaks !== undefined ? widgetData.autoStartBreaks : (widgetMetadata.autoStartBreaks !== undefined ? widgetMetadata.autoStartBreaks : false)
  readonly property bool autoStartWork: widgetData.autoStartWork !== undefined ? widgetData.autoStartWork : (widgetMetadata.autoStartWork !== undefined ? widgetMetadata.autoStartWork : false)
  readonly property bool playSound: widgetData.playSound !== undefined ? widgetData.playSound : (widgetMetadata.playSound !== undefined ? widgetMetadata.playSound : true)
  readonly property real soundVolume: widgetData.soundVolume !== undefined ? widgetData.soundVolume : (widgetMetadata.soundVolume !== undefined ? widgetMetadata.soundVolume : 0.3)
  readonly property bool soundRepeat: widgetData.soundRepeat !== undefined ? widgetData.soundRepeat : (widgetMetadata.soundRepeat !== undefined ? widgetMetadata.soundRepeat : true)
  readonly property string customSoundPath: widgetData.customSoundPath !== undefined ? widgetData.customSoundPath : (widgetMetadata.customSoundPath !== undefined ? widgetMetadata.customSoundPath : "")

  // --- SOUND ---
  readonly property string alarmSoundFile: Qt.resolvedUrl("../../../Assets/Sounds/pomodoro-alarm.mp3").toString().replace("file://", "")
  property string alarmSoundPath: _resolveAlarmSoundPath()

  function _resolveAlarmSoundPath() {
    const custom = customSoundPath.trim();
    return custom.length > 0 ? custom : alarmSoundFile;
  }

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

  implicitWidth: (compactMode ? 320 : 360) * Style.uiScaleRatio * widgetScale
  implicitHeight: (compactMode ? 220 : 340) * Style.uiScaleRatio * widgetScale
  width: implicitWidth
  height: implicitHeight

  function getDurationForMode(mode) {
    if (mode === modeWork)
      return workDurationSeconds;
    if (mode === modeShortBreak)
      return shortBreakDurationSeconds;
    if (mode === modeLongBreak)
      return longBreakDurationSeconds;
    return workDurationSeconds;
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
    onTriggered: {
      root.pomodoroStopAlarm();
    }
  }

  function pomodoroStart(stopSound = true) {
    if (stopSound && root.pomodoroSoundPlaying) {
      SoundService.stopSound(root.alarmSoundPath);
      root.pomodoroSoundPlaying = false;
      alarmLimitTimer.stop();
    }

    if (root.pomodoroRemainingSeconds <= 0) {
      root.pomodoroRemainingSeconds = getDurationForMode(root.pomodoroMode);
      root.pomodoroOriginalTotal = root.pomodoroRemainingSeconds;
    } else if (root.pomodoroOriginalTotal <= 0) {
      root.pomodoroOriginalTotal = root.pomodoroRemainingSeconds;
    }

    root.pomodoroTotalSeconds = root.pomodoroRemainingSeconds;
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
      return "Short Break";
    if (pomodoroMode === modeLongBreak)
      return "Long Break";
    return "Pomodoro";
  }

  NBox {
    anchors.fill: parent
    color: widgetData.showBackground !== false ? (Color.mSurfaceContainerHigh) : "transparent"
    radius: widgetData.roundedCorners !== false ? Style.radiusM : 0
    border.color: widgetData.showBackground !== false ? Color.mOutlineVariant : "transparent"
    border.width: widgetData.showBackground !== false ? 1 : 0
    opacity: widgetData.opacity !== undefined ? widgetData.opacity : 1.0

    ColumnLayout {
      anchors.fill: parent
      anchors.margins: Style.marginM
      spacing: Style.marginM
      clip: true

      RowLayout {
        Layout.fillWidth: true
        spacing: Style.marginS

        NIcon {
          icon: getModeIcon()
          pointSize: Style.fontSizeL
          color: Color.mPrimary
        }

        NText {
          text: "Pomodoro"
          pointSize: Style.fontSizeL
          font.weight: Style.fontWeightBold
          color: Color.mOnSurface
          Layout.fillWidth: true
        }

        Item {
          Layout.alignment: Qt.AlignVCenter
          Layout.preferredWidth: pomodoroSoundPlaying ? (bellIcon.implicitWidth + Style.marginS) : 0
          Layout.preferredHeight: bellIcon.implicitHeight + Style.marginS
          clip: true

          Behavior on Layout.preferredWidth {
            NumberAnimation {
              duration: 150
              easing.type: Easing.InOutQuad
            }
          }

          NIcon {
            id: bellIcon
            anchors.centerIn: parent
            icon: "bell-ringing"
            pointSize: Style.fontSizeXL
            color: bellMouseArea.containsMouse ? Qt.lighter(Color.mError, 1.2) : Color.mError
            opacity: pomodoroSoundPlaying ? 1 : 0

            Behavior on opacity {
              NumberAnimation {
                duration: 150
              }
            }
          }

          MouseArea {
            id: bellMouseArea
            anchors.fill: parent
            hoverEnabled: true
            enabled: pomodoroSoundPlaying
            cursorShape: Qt.PointingHandCursor
            onClicked: pomodoroStopAlarm()
          }
        }

        NText {
          text: "Session " + (pomodoroCompletedSessions + 1) + "/" + sessionsBeforeLongBreak
          pointSize: Style.fontSizeS
          color: Color.mOnSurfaceVariant
        }
      }

      Item {
        id: timerDisplayItem
        Layout.fillWidth: true
        Layout.fillHeight: true
        visible: !compactMode

        Canvas {
          id: progressRing
          anchors.centerIn: parent
          width: Math.min(parent.width, parent.height) * 0.9
          height: width
          visible: pomodoroOriginalTotal > 0 && (pomodoroRunning || pomodoroRemainingSeconds > 0)

          property real progressRatio: {
            if (pomodoroOriginalTotal <= 0)
              return 0;
            const ratio = pomodoroRemainingSeconds / pomodoroOriginalTotal;
            return Math.max(0, Math.min(1, ratio));
          }

          onProgressRatioChanged: requestPaint()

          onPaint: {
            var ctx = getContext("2d");
            if (width <= 0 || height <= 0)
              return;

            var centerX = width / 2;
            var centerY = height / 2;
            var radius = (Math.min(width, height) / 2) - 12;
            if (radius < 0)
              radius = 0;

            ctx.clearRect(0, 0, width, height);

            ctx.lineWidth = 8;
            ctx.lineCap = "round";

            ctx.strokeStyle = Color.mSurfaceContainerHighest;
            ctx.beginPath();
            ctx.arc(centerX, centerY, radius, 0, 2 * Math.PI);
            ctx.stroke();

            ctx.strokeStyle = Color.mPrimary;
            var startAngle = -Math.PI / 2;
            var endAngle = startAngle + 2 * Math.PI * progressRatio;
            ctx.beginPath();
            ctx.arc(centerX, centerY, radius, startAngle, endAngle);
            ctx.stroke();
          }
        }

        ColumnLayout {
          anchors.centerIn: parent
          spacing: Style.marginS

          NText {
            text: getModeName()
            pointSize: Style.fontSizeL
            color: Color.mPrimary
            font.weight: Style.fontWeightSemiBold
            Layout.alignment: Qt.AlignHCenter
          }

          NText {
            text: formatTime(pomodoroRemainingSeconds, pomodoroOriginalTotal)
            pointSize: compactMode ? Style.fontSizeXL : Style.fontSizeXXXL
            font.weight: Style.fontWeightBold
            color: Color.mOnSurface
            font.family: "JetBrainsMono Nerd Font, monospace"
            Layout.alignment: Qt.AlignHCenter
          }

          RowLayout {
            spacing: Style.marginXS
            Layout.alignment: Qt.AlignHCenter

            Repeater {
              model: sessionsBeforeLongBreak
              delegate: Rectangle {
                width: 10 * Style.uiScaleRatio
                height: 10 * Style.uiScaleRatio
                radius: 5 * Style.uiScaleRatio
                color: index < pomodoroCompletedSessions ? Color.mPrimary : Color.mSurfaceContainerHighest
              }
            }
          }
        }
      }

      ColumnLayout {
        Layout.fillWidth: true
        spacing: Style.marginS
        visible: compactMode

        NText {
          text: getModeName() + " - " + (pomodoroCompletedSessions + 1) + "/" + sessionsBeforeLongBreak
          pointSize: Style.fontSizeS
          color: Color.mPrimary
          Layout.alignment: Qt.AlignHCenter
        }

        NText {
          text: formatTime(pomodoroRemainingSeconds, pomodoroOriginalTotal > 0 ? pomodoroOriginalTotal : getDurationForMode(pomodoroMode))
          pointSize: Style.fontSizeXXL
          font.weight: Style.fontWeightBold
          color: Color.mOnSurface
          font.family: "JetBrainsMono Nerd Font, monospace"
          Layout.alignment: Qt.AlignHCenter
        }
      }

      RowLayout {
        Layout.fillWidth: true
        spacing: Style.marginXS
        Layout.alignment: Qt.AlignHCenter

        NButton {
          text: pomodoroRunning ? "Pause" : "Start"
          icon: pomodoroRunning ? "player-pause" : "player-play"
          onClicked: {
            if (pomodoroRunning) {
              pomodoroPause();
            } else {
              pomodoroStart();
            }
          }
          Layout.preferredHeight: 32 * Style.uiScaleRatio
        }

        NButton {
          text: "Reset"
          icon: "refresh"
          type: "secondary"
          onClicked: pomodoroResetSession()
          Layout.preferredHeight: 32 * Style.uiScaleRatio
        }

        NButton {
          text: "Skip"
          icon: "skip-forward"
          type: "secondary"
          onClicked: pomodoroSkip()
          Layout.preferredHeight: 32 * Style.uiScaleRatio
        }

        NButton {
          text: "Reset All"
          icon: "trash"
          type: "danger"
          onClicked: pomodoroResetAll()
          Layout.preferredHeight: 32 * Style.uiScaleRatio
        }
      }
    }
  }
}
