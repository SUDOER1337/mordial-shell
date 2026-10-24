// File: Modules/LockScreen/LockScreenHeader.qml
// =============================================================================
// Island display clock, centered on the lock surface: date line above, giant
// digits stacked below, all lifted with a black shadow instead of dimming the
// background. The user's identity is not shown here — the auth pill carries
// it.
//
// Functions:
//   (declarative component) - no imperative logic
// =============================================================================

import QtQuick
import QtQuick.Effects
import Quickshell
import qs.Commons
import qs.Widgets

// Time and Date Container
Rectangle {
  id: root

  // Display text component shared by all clock strings
  component DisplayText: NText {
    // Shadow-not-scrim: large text lifts itself off the wash
    layer.enabled: true
    layer.effect: MultiEffect {
      shadowEnabled: true
      shadowColor: Qt.rgba(0, 0, 0, Look.textShadowOpacity)
      shadowBlur: 0.4
      shadowVerticalOffset: Look.textShadowOffset
      shadowHorizontalOffset: Look.textShadowOffset * 0.5
    }
  }

  // Use timer-driven properties instead of Time.now to avoid per-frame repaints.
  // Time.now updates every frame (~60+ Hz); these update only when needed.
  property date currentTime: new Date()
  property date currentDate: new Date()

  Timer {
    interval: 1000
    running: true
    repeat: true
    onTriggered: root.currentTime = new Date()
  }

  Timer {
    interval: 60000
    running: true
    repeat: true
    onTriggered: root.currentDate = new Date()
  }

  // Date as a capitalized "Weekday, Month D" line
  readonly property string dateLine: {
    var dateString = Qt.locale().toString(root.currentDate, "dddd, MMMM d");
    return dateString.charAt(0).toUpperCase() + dateString.slice(1);
  }

  readonly property string hourText: Qt.locale().toString(root.currentTime, "HH")
  readonly property string minuteText: Qt.locale().toString(root.currentTime, "mm")

  anchors.fill: parent
  color: "transparent"

  // --- Island display clock, centered on the lock surface ---
  // Date line, then stacked "HH" over "MM". Minutes sit dimmer than hours.
  // Redrawn every minute via the timers above.
  Column {
    id: clockColumn
    anchors.centerIn: parent
    spacing: 0

    // --- Date line ---
    DisplayText {
      anchors.horizontalCenter: parent.horizontalCenter
      text: root.dateLine
      pointSize: 20
      font.weight: Style.fontWeightSemiBold
      color: Look.inkDim
    }

    // --- Digits: stacked "HH" over "MM" ---
    Column {
      anchors.horizontalCenter: parent.horizontalCenter
      spacing: -24

      DisplayText {
        anchors.horizontalCenter: parent.horizontalCenter
        text: root.hourText
        pointSize: 96
        font.weight: Style.fontWeightBold
        color: Look.ink
      }

      DisplayText {
        anchors.horizontalCenter: parent.horizontalCenter
        text: root.minuteText
        pointSize: 96
        font.weight: Style.fontWeightBold
        color: Look.inkMuted
      }
    }
  }
}
