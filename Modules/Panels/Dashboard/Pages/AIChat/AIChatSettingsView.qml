/*
* AI Chat settings view for the Dashboard.
* The chat view (bubbles + input) is swapped out for this in place, so the
* settings stay on the dashboard instead of opening the Settings panel.
* Adapted from unified-ai-panel plugin
* Original author: SUDOER1337 (based on j-1in's work)
* Repository: https://github.com/noctalia-dev/noctalia-plugins
* Licensed under MIT License
*/

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Widgets

Item {
  id: root

  // Ask the page to swap back to the chat view.
  signal requestClose

  // Flush any pending auto-persist edit and return to the chat view.
  function saveAndClose() {
    if (settingsLoader.item && typeof settingsLoader.item.saveSettings === "function")
      settingsLoader.item.saveSettings();
    Settings.saveImmediate();
    root.requestClose();
  }

  ColumnLayout {
    anchors.fill: parent
    spacing: Style.marginM

    // -- Header --
    RowLayout {
      Layout.fillWidth: true
      spacing: Style.marginS

      NIconButton {
        icon: "arrow-left"
        colorFg: Color.mOnSurfaceVariant
        tooltipText: "Back to chat"
        onClicked: root.saveAndClose()
      }

      NText {
        Layout.fillWidth: true
        text: "AI Chat Settings"
        color: Color.mOnSurface
        pointSize: Style.fontSizeM
        font.weight: Font.Bold
      }
    }

    NDivider {
      Layout.fillWidth: true
    }

    // -- Settings content --
    NScrollView {
      id: scrollView
      Layout.fillWidth: true
      Layout.fillHeight: true
      horizontalPolicy: ScrollBar.AlwaysOff
      verticalPolicy: ScrollBar.AsNeeded
      reserveScrollbarSpace: false

      Loader {
        id: settingsLoader
        width: scrollView.availableWidth
        source: "AIChatSettings.qml"
      }
    }
  }
}
