import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Modules.MainScreen
import qs.Services.Hardware
import qs.Services.UI
import qs.Widgets

// === Brightness Panel ===
// A simple brightness slider that controls all capable monitors.
// Functions:
//   getIcon(brightness)     - Choose icon based on brightness level
//   updateBrightness()     - Average brightness across capable monitors
//   applyBrightness(value) - Set brightness on all capable monitors

SmartPanel {
  id: root

  preferredWidth: Math.round(440 * Style.uiScaleRatio)

  panelContent: Item {
    id: panelContent

    property real currentBrightness: 0
    property bool hasCapableMonitors: false
    property real contentPreferredHeight: layout.implicitHeight + Style.margin2L

    Connections {
      target: BrightnessService
      function onMonitorBrightnessChanged() {
        panelContent.updateBrightness();
      }
      function onMonitorsChanged() {
        panelContent.updateBrightness();
      }
      function onDdcMonitorsChanged() {
        panelContent.updateBrightness();
      }
    }

    Component.onCompleted: updateBrightness()

    function getIcon(brightness) // Pick icon by brightness level
    {
      return brightness <= 0.5 ? "brightness-low" : "brightness-high";
    }

    function updateBrightness() // Average brightness across all capable monitors
    {
      var capable = (BrightnessService.monitors || []).filter(m => m && m.brightnessControlAvailable);
      panelContent.hasCapableMonitors = capable.length > 0;
      if (!panelContent.hasCapableMonitors) {
        panelContent.currentBrightness = 0;
        return;
      }
      var total = 0;
      capable.forEach(m => {
                        total += isNaN(m.brightness) ? 0 : m.brightness;
                      });
      panelContent.currentBrightness = total / capable.length;
    }

    function applyBrightness(value) // Set brightness on all capable monitors
    {
      (BrightnessService.monitors || []).forEach(m => {
                                                   if (m && m.brightnessControlAvailable)
                                                   m.setBrightness(value);
                                                 });
    }

    ColumnLayout {
      id: layout
      anchors.fill: parent
      anchors.margins: Style.marginL

      NBox {
        Layout.fillWidth: true
        Layout.preferredHeight: row.implicitHeight + Style.margin2M

        RowLayout {
          id: row
          anchors.fill: parent
          anchors.margins: Style.marginM
          spacing: Style.marginM

          NIcon {
            icon: panelContent.getIcon(panelContent.currentBrightness)
            pointSize: Style.fontSizeXL
            color: Color.mOnSurface
            enabled: panelContent.hasCapableMonitors
          }

          NValueSlider {
            Layout.fillWidth: true
            from: 0
            to: 1
            value: panelContent.currentBrightness
            stepSize: 0.01
            enabled: panelContent.hasCapableMonitors
            onMoved: value => panelContent.applyBrightness(value)
            onPressedChanged: (pressed, value) => panelContent.applyBrightness(value)
          }

          NText {
            text: panelContent.hasCapableMonitors ? Math.round(panelContent.currentBrightness * 100) + "%" : "N/A"
            Layout.preferredWidth: 45
            horizontalAlignment: Text.AlignRight
            Layout.alignment: Qt.AlignVCenter
            color: Color.mOnSurface
            enabled: panelContent.hasCapableMonitors
          }
        }
      }
    }
  }
}
