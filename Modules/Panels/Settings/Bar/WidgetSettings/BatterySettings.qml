import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Commons
import qs.Services.Hardware
import qs.Widgets

ColumnLayout {
  id: root
  spacing: Style.marginM

  // Properties to receive data from parent
  property var screen: null
  property var widgetData: null
  property var widgetMetadata: null

  signal settingsChanged(var settings)

  // Local state
  property string valueDisplayMode: widgetData.displayMode !== undefined ? widgetData.displayMode : widgetMetadata.displayMode
  property string valueDeviceNativePath: widgetData.deviceNativePath !== undefined ? widgetData.deviceNativePath : widgetMetadata.deviceNativePath
  property bool valueShowPowerProfiles: widgetData.showPowerProfiles !== undefined ? widgetData.showPowerProfiles : widgetMetadata.showPowerProfiles
  property bool valueHideIfNotDetected: widgetData.hideIfNotDetected !== undefined ? widgetData.hideIfNotDetected : widgetMetadata.hideIfNotDetected
  property bool valueHideIfIdle: widgetData.hideIfIdle !== undefined ? widgetData.hideIfIdle : widgetMetadata.hideIfIdle

  function saveSettings() {
    var settings = Object.assign({}, widgetData || {});
    if (widgetData && widgetData.id) {
      settings.id = widgetData.id;
    }
    settings.displayMode = valueDisplayMode;
    settings.showPowerProfiles = valueShowPowerProfiles;
    settings.hideIfNotDetected = valueHideIfNotDetected;
    settings.hideIfIdle = valueHideIfIdle;
    settings.deviceNativePath = valueDeviceNativePath;
    settingsChanged(settings);
  }

  NComboBox {
    id: deviceComboBox
    Layout.fillWidth: true
    label: "Battery device"
    description: "Select which battery device to display."
    minimumWidth: 240
    model: BatteryService.deviceModel
    currentKey: root.valueDeviceNativePath
    onSelected: key => {
                  root.valueDeviceNativePath = key;
                  saveSettings();
                }
    defaultValue: widgetMetadata.deviceNativePath
  }

  NComboBox {
    Layout.fillWidth: true
    label: "Display mode"
    description: "Choose how the battery is displayed in the bar."
    minimumWidth: 240
    model: [
      {
        "key": "graphic",
        "name": "Graphical battery"
      },
      {
        "key": "graphic-clean",
        "name": "Graphical battery (no %)"
      },
      {
        "key": "icon-hover",
        "name": "Icon - Show on hover"
      },
      {
        "key": "icon-always",
        "name": "Icon - Always show %"
      },
      {
        "key": "icon-only",
        "name": "Icon only"
      }
    ]
    currentKey: root.valueDisplayMode
    onSelected: key => {
                  root.valueDisplayMode = key;
                  saveSettings();
                }
    defaultValue: widgetMetadata.displayMode
  }

  NToggle {
    label: "Hide when not detected"
    description: "Hide the widget when no battery is detected on the system."
    checked: valueHideIfNotDetected
    onToggled: checked => {
                 valueHideIfNotDetected = checked;
                 saveSettings();
               }
    defaultValue: widgetMetadata.hideIfNotDetected
  }

  NToggle {
    label: "Hide when idle"
    description: "Hide the widget when the battery is not charging or discharging."
    checked: valueHideIfIdle
    onToggled: checked => {
                 valueHideIfIdle = checked;
                 saveSettings();
               }
    defaultValue: widgetMetadata.hideIfIdle
  }

  NDivider {
    Layout.fillWidth: true
  }

  NToggle {
    label: "Show power profile controls"
    description: "Display the power profile selection inside the battery panel."
    checked: valueShowPowerProfiles
    onToggled: checked => {
                 valueShowPowerProfiles = checked;
                 saveSettings();
               }
    defaultValue: widgetMetadata.showPowerProfiles
  }
}
