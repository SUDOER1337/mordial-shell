// File: Modules/LockScreen/LockScreenPanel.qml
// =============================================================================
// Island lock screen UI — a small one-line password pill with custom character
// rendering, icon-only session actions (logout, reboot, shutdown), and a
// compact status readout (battery, keyboard layout, Caps Lock).
// Supports auto-unlock on trusted input.
//
// Functions:
//   doUnlock()                - Attempt to unlock via lockControl
//   startTimer(action)        - Begin countdown for a session action
//   cancelTimer()             - Abort the active countdown
//   executeAction(action)     - Dispatch a session action (logout, shutdown, etc.)
//
// Properties:
//   lockControl               - Required lock state controller
//   passwordInput             - Required TextInput for password entry
//   timerDuration             - Countdown duration from settings
//   timeRemaining             - Seconds left on the active countdown
//   animationsEnabled         - Whether smooth cursor animations are active
// =============================================================================

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Services.Hardware
import qs.Services.Keyboard
import qs.Widgets

Item {
  id: root
  anchors.fill: parent

  required property var lockControl
  required property var batteryIndicator
  required property var keyboardLayout
  required property TextInput passwordInput

  // Whether to enable lock screen animations (smooth cursor blink).
  // Defaults to false to reduce GPU usage.  Set Settings.data.general.lockScreenAnimations = true to restore.
  readonly property bool animationsEnabled: Settings.data.general.lockScreenAnimations || false

  Component.onCompleted: {
    if (Settings.data.general.autoStartAuth) {
      doUnlock();
    }
  }

  function doUnlock() {
    if (lockControl) {
      lockControl.tryUnlock();
    }
  }

  // Timer properties
  readonly property int timerDuration: Settings.data.general.lockScreenCountdownDuration
  property string pendingAction: ""
  property bool timerActive: false
  property int timeRemaining: 0

  // Timer management functions
  function startTimer(action) {
    // Check if global countdown is disabled
    if (!Settings.data.general.enableLockScreenCountdown) {
      executeAction(action);
      return;
    }

    if (timerActive && pendingAction === action) {
      // Second click - execute immediately
      executeAction(action);
      return;
    }

    pendingAction = action;
    timeRemaining = timerDuration;
    timerActive = true;
    countdownTimer.start();
  }

  function cancelTimer() {
    timerActive = false;
    pendingAction = "";
    timeRemaining = 0;
    countdownTimer.stop();
  }

  function executeAction(action) {
    // Stop timer but don't reset other properties yet
    countdownTimer.stop();

    // Execute the action
    switch (action) {
    case "logout":
      CompositorService.logout();
      break;
    case "suspend":
      CompositorService.suspend();
      break;
    case "hibernate":
      CompositorService.hibernate();
      break;
    case "reboot":
      CompositorService.reboot();
      break;
    case "userspaceReboot":
      CompositorService.userspaceReboot();
      break;
    case "shutdown":
      CompositorService.shutdown();
      break;
    }

    // Reset timer state
    cancelTimer();
  }

  // Countdown timer
  Timer {
    id: countdownTimer
    interval: 100
    repeat: true
    onTriggered: {
      timeRemaining -= interval;
      if (timeRemaining <= 0) {
        executeAction(pendingAction);
      }
    }
  }

  // Compact status indicators container (compact mode only)
  Rectangle {
    width: {
      var hasBattery = batteryIndicator.isReady;
      var hasKeyboard = keyboardLayout.currentLayout !== "Unknown";
      var hasCaps = LockKeysService.capsLockOn;
      var hasCapsSlot = hasBattery || hasKeyboard || hasCaps;

      var visibleCount = 0;
      if (hasBattery)
        visibleCount++;
      if (hasKeyboard)
        visibleCount++;
      if (hasCapsSlot)
        visibleCount++;

      if (visibleCount >= 3) {
        return 280;
      } else if (visibleCount === 2) {
        return 200;
      } else if (visibleCount === 1) {
        return 120;
      } else {
        return 0;
      }
    }
    height: 40
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.bottom: parent.bottom
    anchors.bottomMargin: 96 + (Settings.data.general.compactLockScreen ? 116 : 220)
    topLeftRadius: Style.radiusL
    topRightRadius: Style.radiusL
    color: Look.surface
    visible: Settings.data.general.compactLockScreen && (batteryIndicator.isReady || keyboardLayout.currentLayout !== "Unknown" || LockKeysService.capsLockOn)

    RowLayout {
      id: compactStatusRow
      anchors.centerIn: parent
      spacing: Style.marginL

      // Battery indicator
      RowLayout {
        spacing: Style.marginS
        visible: batteryIndicator.isReady

        NIcon {
          icon: batteryIndicator.icon
          pointSize: Style.fontSizeM
          color: batteryIndicator.charging ? Color.mPrimary : Color.mOnSurfaceVariant
        }

        NText {
          text: Math.round(batteryIndicator.percent) + "%"
          color: Color.mOnSurfaceVariant
          pointSize: Style.fontSizeM
        }
      }

      // Keyboard layout indicator
      RowLayout {
        spacing: 6
        visible: keyboardLayout.currentLayout !== "Unknown"

        NIcon {
          icon: "keyboard"
          pointSize: Style.fontSizeM
          color: Color.mOnSurfaceVariant
        }

        NText {
          text: keyboardLayout.currentLayout
          color: Color.mOnSurfaceVariant
          pointSize: Style.fontSizeM
          elide: Text.ElideRight
        }
      }

      // Caps Lock indicator
      RowLayout {
        spacing: 6
        visible: batteryIndicator.isReady || keyboardLayout.currentLayout !== "Unknown" || LockKeysService.capsLockOn

        NIcon {
          icon: "lock"
          pointSize: Style.fontSizeM
          color: LockKeysService.capsLockOn ? Color.mPrimary : Qt.alpha(Color.mOnSurfaceVariant, 0.5)
        }

        NText {
          text: "Caps Lock"
          color: LockKeysService.capsLockOn ? Color.mOnSurfaceVariant : Qt.alpha(Color.mOnSurfaceVariant, 0.65)
          pointSize: Style.fontSizeM
          elide: Text.ElideRight
        }
      }
    }
  }

  // Bottom container with weather, password input and controls
  Rectangle {
    id: bottomContainer

    // Support for removing the session/power buttons at the bottom.
    readonly property int deltaY: Settings.data.general.showSessionButtonsOnLockScreen ? 0 : (Settings.data.general.compactLockScreen ? 36 : 48) + 14

    anchors.horizontalCenter: parent.horizontalCenter
    anchors.bottom: parent.bottom
    anchors.bottomMargin: 100 + bottomContainer.deltaY
    radius: Style.radiusL
    // Island: the original card is gone — only the small pill (plus the
    // optional icon actions) floats on the wash
    color: "transparent"

    // Island: wrap just the pill (plus icon actions when enabled).
    // Pill row: 14 + 52 + 18; actions row: 18 + 48 (36 compact) + 14.
    height: {
      if (!Settings.data.general.showSessionButtonsOnLockScreen)
        return 14 + 52 + 14;
      return Settings.data.general.compactLockScreen ? 14 + 52 + 18 + 36 + 14 : 14 + 52 + 18 + 48 + 14;
    }

    width: 560

    ColumnLayout {
      anchors.fill: parent
      anchors.margins: 14
      spacing: Style.marginL

      // Password input
      RowLayout {
        Layout.fillWidth: true
        spacing: 0

        // Fill-width spacer centers the pill
        Item {
          Layout.fillWidth: true
        }

        Rectangle {
          id: passwordInputContainer

          // Island failure state for the armed-red border + shake
          readonly property bool islandShowFailure: root.lockControl ? root.lockControl.showFailure : false
          onIslandShowFailureChanged: {
            if (islandShowFailure)
              islandShakeAnim.restart();
          }

          // Island: small one-line pill
          Layout.fillWidth: false
          Layout.preferredWidth: 260
          Layout.preferredHeight: 52
          radius: 26
          color: Look.surface
          border.color: islandShowFailure ? Look.statusBad : (passwordInput.activeFocus ? Color.mPrimary : Look.border)
          border.width: passwordInput.activeFocus ? 2 : 1

          // Island: shake the pill on wrong-password feedback
          transform: Translate {
            id: islandShake
            x: 0
          }

          SequentialAnimation {
            id: islandShakeAnim
            running: false
            NumberAnimation {
              target: islandShake
              property: "x"
              to: Look.shakeAmplitude
              duration: Look.shakeInterval
            }
            NumberAnimation {
              target: islandShake
              property: "x"
              to: -Look.shakeAmplitude
              duration: Look.shakeInterval
            }
            NumberAnimation {
              target: islandShake
              property: "x"
              to: Look.shakeAmplitude
              duration: Look.shakeInterval
            }
            NumberAnimation {
              target: islandShake
              property: "x"
              to: 0
              duration: Look.shakeInterval
            }
          }

          property bool passwordVisible: false

          // Ctrl + A to highlight the portion
          Shortcut {
            sequence: StandardKey.SelectAll
            enabled: passwordInput.activeFocus
            onActivated: passwordInput.selectAll()
          }

          // Esc to clear selection
          Shortcut {
            sequences: [StandardKey.Cancel]
            enabled: passwordInput.activeFocus && passwordInput.selectionStart !== passwordInput.selectionEnd
            onActivated: passwordInput.deselect()
          }

          Row {
            anchors.left: parent.left
            anchors.leftMargin: 14
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.marginL

            Row {
              spacing: 0

              Rectangle {
                width: 2
                height: 20
                color: Look.ink
                visible: passwordInput.activeFocus && passwordInput.text.length === 0
                anchors.verticalCenter: parent.verticalCenter

                // Smooth fade animation (when animations enabled)
                SequentialAnimation on opacity {
                  loops: Animation.Infinite
                  running: root.animationsEnabled && passwordInput.activeFocus && passwordInput.text.length === 0
                  NumberAnimation {
                    to: 0
                    duration: 530
                  }
                  NumberAnimation {
                    to: 1
                    duration: 530
                  }
                }

                // Simple toggle (when animations disabled) — no per-frame repaints
                Timer {
                  interval: 530
                  running: !root.animationsEnabled && passwordInput.activeFocus && passwordInput.text.length === 0
                  repeat: true
                  onTriggered: parent.opacity = parent.opacity > 0.5 ? 0 : 1
                }
              }

              // Host for dots / plain text and the caret (caret x follows passwordInput.cursorPosition)
              Item {
                id: passwordVisualHost
                height: 20
                width: passwordInputContainer.passwordVisible ? Math.min(visiblePasswordPlainText.implicitWidth, 550) : Math.min(passwordDisplayContent.width, 550)
                anchors.verticalCenter: parent.verticalCenter

                readonly property real caretVisualX: {
                  const len = passwordInput.text.length;
                  if (len <= 0)
                    return 0;
                  if (passwordInputContainer.passwordVisible) {
                    const adv = passwordCaretFontMetrics.advanceWidth(passwordInput.text.substring(0, passwordInput.cursorPosition));
                    return Math.max(0, Math.min(adv, width));
                  }
                  const w = passwordDisplayContent.width;
                  if (w <= 0)
                    return 0;
                  return Math.max(0, Math.min((passwordInput.cursorPosition / len) * w, width));
                }

                // Password dots display with selection support
                Item {
                  width: Math.min(passwordDisplayContent.width, 550)
                  height: 20
                  visible: passwordInput.text.length > 0 && !passwordInputContainer.passwordVisible
                  anchors.left: parent.left
                  anchors.verticalCenter: parent.verticalCenter
                  clip: true

                  // Proportional selection highlight behind the dots
                  Rectangle {
                    id: selectionHighlight
                    visible: passwordInput.selectionStart !== passwordInput.selectionEnd && passwordInput.text.length > 0
                    color: Qt.alpha(Color.mPrimary, 0.8)
                    height: parent.height + Style.marginS
                    anchors.verticalCenter: parent.verticalCenter
                    x: (passwordInput.selectionStart / passwordInput.text.length) * passwordDisplayContent.width
                    width: ((passwordInput.selectionEnd - passwordInput.selectionStart) / passwordInput.text.length) * passwordDisplayContent.width
                  }

                  Row {
                    id: passwordDisplayContent
                    spacing: Style.marginXXXS
                    anchors.verticalCenter: parent.verticalCenter

                    Repeater {
                      id: iconRepeater
                      model: ScriptModel {
                        values: Array(passwordInput.text.length)
                      }

                      property list<string> passwordChars: ["circle-filled", "pentagon-filled", "michelin-star-filled", "square-rounded-filled", "guitar-pick-filled", "blob-filled", "triangle-filled"]

                      NIcon {
                        id: icon

                        required property int index
                        // This will be called with index = -1 when the TextInput is deleted
                        // So we make sur index is positive to avoid warning on array accesses
                        property bool drawCustomChar: index >= 0 && Settings.data.general.passwordChars
                        // Flip color when this dot falls inside the active selection range
                        property bool isSelected: index >= 0 && passwordInput.selectionStart !== passwordInput.selectionEnd && index >= passwordInput.selectionStart && index < passwordInput.selectionEnd

                        icon: drawCustomChar ? iconRepeater.passwordChars[index % iconRepeater.passwordChars.length] : "circle-filled"
                        pointSize: Style.fontSizeL
                        color: isSelected ? Color.mPrimary : Look.ink
                        opacity: 1.0
                        scale: animationsEnabled ? 0.5 : 1
                        ParallelAnimation {
                          id: iconAnim
                          NumberAnimation {
                            target: icon
                            properties: "scale"
                            to: 1
                            duration: Style.animationFast
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: Easing.OutInBounce
                          }
                        }
                        Component.onCompleted: {
                          if (animationsEnabled) {
                            iconAnim.start();
                          }
                        }
                      }
                    }
                  }

                  // Mouse area for click-to-position and drag-to-select
                  MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.IBeamCursor

                    property int dragStartPos: 0
                    property bool pendingSelectAll: false

                    // Resets double-click state if user pauses too long between clicks
                    Timer {
                      id: doubleClickResetTimer
                      interval: 600
                      onTriggered: parent.pendingSelectAll = false
                    }

                    function charIndexFromX(mouseX) {
                      if (passwordInput.text.length === 0)
                        return 0;
                      var charWidth = passwordDisplayContent.width / passwordInput.text.length;
                      // floor so clicking anywhere on a dot selects that dot, not the next
                      return Math.max(0, Math.min(passwordInput.text.length - 1, Math.floor(mouseX / charWidth)));
                    }

                    onPressed: function (mouse) {
                      doubleClickResetTimer.stop();
                      passwordInput.forceActiveFocus();
                      dragStartPos = charIndexFromX(mouse.x);
                      passwordInput.cursorPosition = dragStartPos;
                    }

                    onPositionChanged: function (mouse) {
                      pendingSelectAll = false;
                      var curPos = charIndexFromX(mouse.x);
                      if (curPos <= dragStartPos) {
                        passwordInput.select(curPos, dragStartPos + 1);
                      } else {
                        passwordInput.select(dragStartPos, curPos + 1);
                      }
                    }

                    onDoubleClicked: function (mouse) {
                      passwordInput.forceActiveFocus();
                      if (pendingSelectAll) {
                        passwordInput.selectAll();
                        pendingSelectAll = false;
                      } else {
                        var pos = charIndexFromX(mouse.x);
                        passwordInput.select(pos, Math.min(pos + 1, passwordInput.text.length));
                        pendingSelectAll = true;
                        doubleClickResetTimer.restart();
                      }
                    }
                  }
                }

                NText {
                  id: visiblePasswordPlainText
                  text: passwordInput.text
                  color: Color.mPrimary
                  pointSize: Style.fontSizeM
                  visible: passwordInput.text.length > 0 && passwordInputContainer.passwordVisible
                  anchors.left: parent.left
                  anchors.verticalCenter: parent.verticalCenter
                  elide: Text.ElideRight
                  width: Math.min(implicitWidth, 550)
                }

                FontMetrics {
                  id: passwordCaretFontMetrics
                  font: visiblePasswordPlainText.font
                }

                Rectangle {
                  width: 2
                  height: 20
                  x: passwordVisualHost.caretVisualX
                  color: Look.ink
                  // Hide the cursor when text is selected
                  visible: passwordInput.activeFocus && passwordInput.text.length > 0 && passwordInput.selectionStart === passwordInput.selectionEnd
                  anchors.verticalCenter: parent.verticalCenter

                  // Smooth fade animation (when animations enabled)
                  SequentialAnimation on opacity {
                    loops: Animation.Infinite
                    running: root.animationsEnabled && passwordInput.activeFocus && passwordInput.text.length > 0 && passwordInput.selectionStart === passwordInput.selectionEnd
                    NumberAnimation {
                      to: 0
                      duration: 530
                    }
                    NumberAnimation {
                      to: 1
                      duration: 530
                    }
                  }

                  // Simple toggle (when animations disabled) — no per-frame repaints
                  Timer {
                    interval: 530
                    running: !root.animationsEnabled && passwordInput.activeFocus && passwordInput.text.length > 0 && passwordInput.selectionStart === passwordInput.selectionEnd
                    repeat: true
                    onTriggered: parent.opacity = parent.opacity > 0.5 ? 0 : 1
                  }
                }
              }
            }
          }

          // Eye button to toggle password visibility
          Rectangle {
            anchors.right: parent.right
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            width: 36
            height: 36
            radius: Math.min(Style.iRadiusL, width / 2)
            color: eyeButtonArea.containsMouse ? Look.surfaceHover : "transparent"
            visible: passwordInput.text.length > 0
            enabled: !lockContext || !lockContext.unlockInProgress

            NIcon {
              anchors.centerIn: parent
              icon: parent.parent.passwordVisible ? "eye-off" : "eye"
              pointSize: Style.fontSizeM
              color: eyeButtonArea.containsMouse ? Color.mPrimary : Look.ink

              Behavior on color {
                ColorAnimation {
                  duration: Style.animationFast
                  easing.type: Easing.OutCubic
                }
              }
            }

            MouseArea {
              id: eyeButtonArea
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: parent.parent.passwordVisible = !parent.parent.passwordVisible
            }

            Behavior on color {
              ColorAnimation {
                duration: Style.animationFast
                easing.type: Easing.OutCubic
              }
            }
          }

          Behavior on border.color {
            ColorAnimation {
              duration: Style.animationFast
              easing.type: Easing.OutCubic
            }
          }
        }

        Item {
          Layout.preferredWidth: 0
          Layout.fillWidth: true
        }
      }

      // Session control actions (icon buttons)
      RowLayout {
        id: sessionButtonRow
        Layout.fillWidth: true
        Layout.preferredHeight: Settings.data.general.compactLockScreen ? 36 : 48
        Layout.alignment: Qt.AlignHCenter
        spacing: Style.marginM
        visible: Settings.data.general.showSessionButtonsOnLockScreen

        readonly property real buttonsSize: Settings.data.general.compactLockScreen ? 36 : 48

        NIconButton {
          icon: "logout"
          tooltipText: "Logout"
          baseSize: sessionButtonRow.buttonsSize
          colorBg: Look.surface
          colorBgHover: Look.surfaceHover
          colorFg: Look.ink
          colorFgHover: Look.ink
          onClicked: startTimer("logout")
        }

        NIconButton {
          icon: "suspend"
          tooltipText: "Suspend"
          baseSize: sessionButtonRow.buttonsSize
          colorBg: Look.surface
          colorBgHover: Look.surfaceHover
          colorFg: Look.ink
          colorFgHover: Look.ink
          onClicked: startTimer("suspend")
        }

        NIconButton {
          icon: "hibernate"
          tooltipText: "Hibernate"
          visible: Settings.data.general.showHibernateOnLockScreen
          baseSize: sessionButtonRow.buttonsSize
          colorBg: Look.surface
          colorBgHover: Look.surfaceHover
          colorFg: Look.ink
          colorFgHover: Look.ink
          onClicked: startTimer("hibernate")
        }

        NIconButton {
          icon: "reboot"
          tooltipText: "Reboot"
          baseSize: sessionButtonRow.buttonsSize
          colorBg: Look.surface
          colorBgHover: Look.surfaceHover
          colorFg: Look.ink
          colorFgHover: Look.ink
          onClicked: startTimer("reboot")
        }

        NIconButton {
          icon: "shutdown"
          tooltipText: "Shutdown"
          baseSize: sessionButtonRow.buttonsSize
          // Armed-red: shutdown carries the destructive accent
          colorBg: Look.statusBad
          colorBgHover: Qt.alpha(Look.statusBad, 0.85)
          colorFg: Look.ink
          colorFgHover: Look.ink
          onClicked: startTimer("shutdown")
        }
      }
    }
  }
}
