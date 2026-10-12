import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Services.System
import qs.Services.UI
import qs.Widgets

ColumnLayout {
  id: root
  spacing: Style.marginL
  Layout.fillWidth: true
  Layout.fillHeight: true

  ColumnLayout {
    spacing: Style.marginL
    Layout.fillWidth: true

    NComboBox {
      id: dashboardPosition
      label: "Position"
      description: "Choose where the dashboard panel appears when opened."
      Layout.fillWidth: true
      model: [
        {
          "key": "close_to_bar_button",
          "name": "Close to bar button"
        },
        {
          "key": "center",
          "name": "Center"
        },
        {
          "key": "top_center",
          "name": "Top center"
        },
        {
          "key": "top_left",
          "name": "Top left"
        },
        {
          "key": "top_right",
          "name": "Top right"
        },
        {
          "key": "bottom_center",
          "name": "Bottom center"
        },
        {
          "key": "bottom_left",
          "name": "Bottom left"
        },
        {
          "key": "bottom_right",
          "name": "Bottom right"
        }
      ]
      currentKey: Settings.data.dashboard.position
      onSelected: function (key) {
        Settings.data.dashboard.position = key;
      }
      defaultValue: Settings.getDefaultValue("dashboard.position")
    }

    NComboBox {
      id: diskPathComboBox
      Layout.fillWidth: true
      label: "System monitor disk path"
      description: "Select which disk mount point the system monitor card in the dashboard should monitor."
      model: {
        const paths = Object.keys(SystemStatService.diskPercents).sort();
        return paths.map(path => ({
                                    key: path,
                                    name: path
                                  }));
      }
      currentKey: Settings.data.dashboard.diskPath || "/"
      onSelected: key => Settings.data.dashboard.diskPath = key
      defaultValue: Settings.getDefaultValue("dashboard.diskPath") || "/"
    }

    NValueSlider {
      Layout.fillWidth: true
      label: "Panel width"
      description: "Width of the dashboard panel in pixels. The same size is used for every page, and the panel shrinks to fit if it does not fit on screen. Below about 1400px the four Home columns start compressing."
      from: 1200
      to: 2000
      stepSize: 20
      showReset: true
      value: Settings.data.dashboard.panelWidth
      defaultValue: Settings.getDefaultValue("dashboard.panelWidth")
      onMoved: value => Settings.data.dashboard.panelWidth = value
      text: Math.round(Settings.data.dashboard.panelWidth) + " px"
    }

    NValueSlider {
      Layout.fillWidth: true
      label: "Panel height"
      description: "Height of the dashboard panel in pixels. Media and calendar columns scroll when the panel is shorter than their content."
      from: 400
      to: 1200
      stepSize: 20
      showReset: true
      value: Settings.data.dashboard.panelHeight
      defaultValue: Settings.getDefaultValue("dashboard.panelHeight")
      onMoved: value => Settings.data.dashboard.panelHeight = value
      text: Math.round(Settings.data.dashboard.panelHeight) + " px"
    }
  }

  Rectangle {
    Layout.fillHeight: true
  }
}
