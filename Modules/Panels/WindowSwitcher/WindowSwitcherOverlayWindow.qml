import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets

import qs.Commons
import qs.Services.UI
import qs.Widgets

// Alt-Tab style switcher overlay.
// One layer-shell window per screen; only the screen hosting the focused
// window is shown. State and selection live in WindowSwitcherService.
Variants {
  id: switcherVariants

  model: Quickshell.screens

  delegate: Loader {
    id: windowLoader

    required property ShellScreen modelData

    active: WindowSwitcherService.isOpen && WindowSwitcherService.screen === modelData

    sourceComponent: PanelWindow {
      id: overlay
      screen: windowLoader.modelData

      anchors {
        top: true
        bottom: true
        left: true
        right: true
      }

      color: "transparent"

      WlrLayershell.namespace: "mordial-window-switcher-" + (screen?.name || "unknown")
      WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
      WlrLayershell.layer: WlrLayer.Overlay
      WlrLayershell.exclusionMode: ExclusionMode.Ignore

      readonly property int itemCount: WindowSwitcherService.items.length
      readonly property int columns: {
        if (itemCount <= 0)
          return 1;
        return Math.min(6, Math.max(1, Math.ceil(Math.sqrt(itemCount))));
      }
      readonly property int rows: itemCount <= 0 ? 1 : Math.ceil(itemCount / columns)
      readonly property real cellW: Math.round(190 * Style.uiScaleRatio)
      readonly property real cellH: Math.round(140 * Style.uiScaleRatio)
      readonly property real gridW: columns * cellW + (columns - 1) * Style.marginS
      readonly property real gridH: rows * cellH + (rows - 1) * Style.marginS
      readonly property real headerH: Math.round(48 * Style.uiScaleRatio)
      readonly property real cardW: Math.min(width - Style.margin2L * 2, gridW + Style.marginL * 2)
      readonly property real cardH: Math.min(height - Style.margin2L * 2, gridH + headerH + Style.marginL * 2 + Style.marginS)

      // Dimmer - click outside the card cancels.
      Rectangle {
        anchors.fill: parent
        color: Qt.alpha(Color.mSurface, Settings.data.general.dimmerOpacity)

        MouseArea {
          anchors.fill: parent
          onClicked: WindowSwitcherService.cancel()
        }
      }

      NDropShadow {
        source: card
        anchors.fill: card
        autoPaddingEnabled: true
      }

      NBox {
        id: card
        anchors.centerIn: parent
        width: overlay.cardW
        height: overlay.cardH
        radius: Style.radiusL
        color: Color.mSurfaceVariant
        forceOpaque: true

        ColumnLayout {
          anchors.fill: parent
          anchors.margins: Style.marginL
          spacing: Style.marginS

          GridLayout {
            Layout.alignment: Qt.AlignHCenter
            columns: overlay.columns
            rowSpacing: Style.marginS
            columnSpacing: Style.marginS

            Repeater {
              model: WindowSwitcherService.items

              delegate: Rectangle {
                id: tile

                required property var modelData
                required property int index

                readonly property bool selected: index === WindowSwitcherService.selectedIndex

                Layout.preferredWidth: overlay.cellW
                Layout.preferredHeight: overlay.cellH
                radius: Style.radiusM
                color: selected ? Color.mHover : Color.mSurface
                border.width: selected ? Style.borderM : 0
                border.color: Color.mPrimary

                Behavior on color {
                  ColorAnimation {
                    duration: Style.animationFast
                    easing.type: Easing.OutCirc
                  }
                }

                ColumnLayout {
                  anchors.fill: parent
                  anchors.margins: Style.marginS
                  spacing: Style.marginXS

                  Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    IconImage {
                      anchors.centerIn: parent
                      width: Math.min(parent.width, parent.height)
                      height: width
                      source: ThemeIcons.iconFromName(modelData.icon, "application-x-executable")
                      asynchronous: true
                    }
                  }

                  NText {
                    Layout.fillWidth: true
                    text: modelData.title || modelData.appId || ""
                    pointSize: Style.fontSizeS
                    color: tile.selected ? Color.mOnHover : Color.mOnSurface
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.Wrap
                    maximumLineCount: 2
                    elide: Text.ElideRight
                  }
                }

                MouseArea {
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onEntered: WindowSwitcherService.selectedIndex = tile.index
                  onClicked: {
                    WindowSwitcherService.selectedIndex = tile.index;
                    WindowSwitcherService.commit();
                  }
                }
              }
            }
          }

          NText {
            Layout.fillWidth: true
            Layout.preferredHeight: overlay.headerH - Style.marginS
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            pointSize: Style.fontSizeM
            font.weight: Style.fontWeightBold
            color: Color.mOnSurface
            elide: Text.ElideRight
            text: {
              var items = WindowSwitcherService.items;
              var idx = WindowSwitcherService.selectedIndex;
              if (idx < 0 || idx >= items.length)
                return "";
              var item = items[idx];
              var name = item.title || item.appId || "";
              return name + "  (" + (idx + 1) + "/" + items.length + ")";
            }
          }
        }
      }
    }
  }
}
