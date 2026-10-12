/*
* AI Chat page for Agnoctural Shell
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

Rectangle {
  id: root
  color: Color.mSurfaceVariant
  radius: Style.radiusL
  clip: true

  property ShellScreen screen

  property var mainInstance: null
  // When true the chat UI is swapped out for the inline settings view.
  property bool settingsMode: false

  // Reset to the chat view whenever the page is (re)shown.
  function onPageShown() {
    settingsMode = false;
  }

  Component.onCompleted: {
    // Initialize the AI Chat main instance
    var component = Qt.createComponent("AIChat/AIChatMain.qml");
    if (component.status === Component.Ready) {
      mainInstance = component.createObject(root);
      if (mainInstance) {
        Logger.i("AIChatPage", "AI Chat main instance created");
      }
    } else if (component.status === Component.Error) {
      Logger.e("AIChatPage", "Failed to load AIChatMain:", component.errorString());
    } else {
      component.statusChanged.connect(function () {
        if (component.status === Component.Ready) {
          mainInstance = component.createObject(root);
          if (mainInstance) {
            Logger.i("AIChatPage", "AI Chat main instance created (async)");
          }
        } else if (component.status === Component.Error) {
          Logger.e("AIChatPage", "Failed to load AIChatMain:", component.errorString());
        }
      });
    }
  }

  // Fallback - show a message if main instance fails to load
  Item {
    anchors.fill: parent
    visible: !mainInstance

    ColumnLayout {
      anchors.centerIn: parent
      spacing: Style.marginM

      NIcon {
        Layout.alignment: Qt.AlignHCenter
        icon: "sparkles"
        color: Color.mOnSurfaceVariant
        pointSize: Style.fontSizeXXL * 2
        applyUiScale: false
      }

      NText {
        Layout.alignment: Qt.AlignHCenter
        text: "AI Chat"
        color: Color.mOnSurfaceVariant
        pointSize: Style.fontSizeL
        font.weight: Font.Medium
      }

      NText {
        Layout.alignment: Qt.AlignHCenter
        text: "AI Chat is unavailable."
        color: Color.mOnSurfaceVariant
        pointSize: Style.fontSizeS
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.WordWrap
        Layout.maximumWidth: parent ? parent.width * 0.8 : 300
      }
    }
  }

  // Load the AI Chat view, or its inline settings when requested
  Loader {
    id: aiChatLoader
    anchors.fill: parent
    anchors.margins: Style.marginM
    active: mainInstance !== null
    source: root.settingsMode ? "AIChat/AIChatSettingsView.qml" : "AIChat/AIChatView.qml"

    onLoaded: {
      // Only the chat view carries a mainInstance; the settings view has none.
      if (!root.settingsMode && item) {
        item.mainInstance = mainInstance;
      }
    }
  }

  Connections {
    target: aiChatLoader.item
    ignoreUnknownSignals: true

    // Settings button on the chat view: swap the chat UI for the settings UI.
    function onRequestSettings() {
      root.settingsMode = true;
    }

    // Back on the settings view: swap back to the chat UI.
    function onRequestClose() {
      root.settingsMode = false;
    }
  }
}
