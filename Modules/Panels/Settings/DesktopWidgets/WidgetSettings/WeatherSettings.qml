import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Commons
import qs.Widgets

ColumnLayout {
  id: root
  spacing: Style.marginM

  property var widgetData: null
  property var widgetMetadata: null

  signal settingsChanged(var settings)

  property bool valueShowBackground: widgetData.showBackground !== undefined ? widgetData.showBackground : widgetMetadata.showBackground
  property bool valueRoundedCorners: widgetData.roundedCorners !== undefined ? widgetData.roundedCorners : widgetMetadata.roundedCorners

  function saveSettings() {
    var settings = Object.assign({}, widgetData || {});
    settings.showBackground = valueShowBackground;
    settings.roundedCorners = valueRoundedCorners;
    settingsChanged(settings);
  }

  NToggle {
    Layout.fillWidth: true
    label: "Show background"
    description: "Show the background container for the weather widget."
    checked: valueShowBackground
    onToggled: checked => {
                 valueShowBackground = checked;
                 saveSettings();
               }
    defaultValue: widgetMetadata.showBackground
  }

  NToggle {
    Layout.fillWidth: true
    visible: valueShowBackground
    label: "Rounded corners"
    description: "Use rounded corners for the widget background."
    checked: valueRoundedCorners
    onToggled: checked => {
                 valueRoundedCorners = checked;
                 saveSettings();
               }
    defaultValue: widgetMetadata.roundedCorners
  }
}
