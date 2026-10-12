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

  property int valueWidth: widgetData.width !== undefined ? widgetData.width : widgetMetadata.width
  property int valueHeight: widgetData.height !== undefined ? widgetData.height : widgetMetadata.height
  property string valueVisualizerType: widgetData.visualizerType !== undefined ? widgetData.visualizerType : widgetMetadata.visualizerType
  property string valueColorName: widgetData.colorName !== undefined ? widgetData.colorName : widgetMetadata.colorName
  property bool valueHideWhenIdle: widgetData.hideWhenIdle !== undefined ? widgetData.hideWhenIdle : widgetMetadata.hideWhenIdle
  property bool valueShowBackground: widgetData.showBackground !== undefined ? widgetData.showBackground : widgetMetadata.showBackground
  property bool valueRoundedCorners: widgetData.roundedCorners !== undefined ? widgetData.roundedCorners : widgetMetadata.roundedCorners

  function saveSettings() {
    var settings = Object.assign({}, widgetData || {});
    settings.width = valueWidth;
    settings.height = valueHeight;
    settings.visualizerType = valueVisualizerType;
    settings.colorName = valueColorName;
    settings.hideWhenIdle = valueHideWhenIdle;
    settings.showBackground = valueShowBackground;
    settings.roundedCorners = valueRoundedCorners;
    settingsChanged(settings);
  }

  NTextInput {
    id: widthInput
    Layout.fillWidth: true
    label: "Width"
    description: "Custom component width."
    text: String(valueWidth)
    placeholderText: "Enter width in pixels"
    inputMethodHints: Qt.ImhDigitsOnly
    onEditingFinished: {
      const parsed = parseInt(text);
      if (!isNaN(parsed) && parsed > 0) {
        valueWidth = parsed;
        saveSettings();
      } else {
        text = String(valueWidth);
      }
    }
    defaultValue: String(widgetMetadata.width)
  }

  NTextInput {
    id: heightInput
    Layout.fillWidth: true
    label: "Height"
    description: "Custom component width."
    text: String(valueHeight)
    placeholderText: "Enter width in pixels"
    inputMethodHints: Qt.ImhDigitsOnly
    onEditingFinished: {
      const parsed = parseInt(text);
      if (!isNaN(parsed) && parsed > 0) {
        valueHeight = parsed;
        saveSettings();
      } else {
        text = String(valueHeight);
      }
    }
    defaultValue: String(widgetMetadata.height)
  }

  NComboBox {
    Layout.fillWidth: true
    label: "Visualization type"
    description: "Choose a visualization type."
    model: [
      {
        "key": "linear",
        "name": "Linear"
      },
      {
        "key": "mirrored",
        "name": "Mirrored"
      },
      {
        "key": "wave",
        "name": "Wave"
      }
    ]
    currentKey: valueVisualizerType
    onSelected: key => {
                  valueVisualizerType = key;
                  saveSettings();
                }
    defaultValue: widgetMetadata.visualizerType
  }

  NColorChoice {
    Layout.fillWidth: true
    label: "Fill color"
    description: "Select the color for the visualizer."
    currentKey: valueColorName
    onSelected: key => {
                  valueColorName = key;
                  saveSettings();
                }
    defaultValue: widgetMetadata.colorName
  }

  NToggle {
    Layout.fillWidth: true
    label: "Hide when no media is playing"
    description: "When enabled, the visualizer is hidden unless a player is actively playing."
    checked: valueHideWhenIdle
    onToggled: checked => {
                 valueHideWhenIdle = checked;
                 saveSettings();
               }
    defaultValue: widgetMetadata.hideWhenIdle
  }

  NDivider {
    Layout.fillWidth: true
  }

  NToggle {
    Layout.fillWidth: true
    label: "Show background"
    description: "Show the background container."
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
    description: "Enable rounded corners on the widget edges."
    checked: valueRoundedCorners
    onToggled: checked => {
                 valueRoundedCorners = checked;
                 saveSettings();
               }
    defaultValue: widgetMetadata.roundedCorners
  }
}
