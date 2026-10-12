import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Commons
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
  property string valueMiddleClickCommand: widgetData.middleClickCommand !== undefined ? widgetData.middleClickCommand : widgetMetadata.middleClickCommand
  property string valueIconColor: widgetData.iconColor !== undefined ? widgetData.iconColor : widgetMetadata.iconColor
  property string valueTextColor: widgetData.textColor !== undefined ? widgetData.textColor : widgetMetadata.textColor

  function saveSettings() {
    var settings = Object.assign({}, widgetData || {});
    settings.displayMode = valueDisplayMode;
    settings.middleClickCommand = valueMiddleClickCommand;
    settings.iconColor = valueIconColor;
    settings.textColor = valueTextColor;
    settingsChanged(settings);
  }

  NComboBox {
    label: "Display mode"
    description: "Choose how you'd like this value to appear."
    minimumWidth: 200
    model: [
      {
        "key": "onhover",
        "name": "On hover"
      },
      {
        "key": "alwaysShow",
        "name": "Always show"
      },
      {
        "key": "alwaysHide",
        "name": "Always hide"
      }
    ]
    currentKey: valueDisplayMode
    onSelected: key => {
                  valueDisplayMode = key;
                  saveSettings();
                }
    defaultValue: widgetMetadata.displayMode
  }

  NColorChoice {
    label: "Select icon color"
    currentKey: valueIconColor
    onSelected: key => {
                  valueIconColor = key;
                  saveSettings();
                }
    defaultValue: widgetMetadata.iconColor
  }

  NColorChoice {
    currentKey: valueTextColor
    onSelected: key => {
                  valueTextColor = key;
                  saveSettings();
                }
    defaultValue: widgetMetadata.textColor
  }

  // Middle click command
  NTextInput {
    label: "Middle click"
    description: "Command to execute when the button is middle-clicked."
    placeholderText: "pwvucontrol || pavucontrol"
    text: valueMiddleClickCommand
    onTextChanged: {
      valueMiddleClickCommand = text;
      saveSettings();
    }
    defaultValue: widgetMetadata.middleClickCommand
  }
}
