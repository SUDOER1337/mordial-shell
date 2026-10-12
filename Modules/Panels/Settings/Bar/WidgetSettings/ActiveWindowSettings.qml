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
  property bool valueShowIcon: widgetData.showIcon !== undefined ? widgetData.showIcon : widgetMetadata.showIcon
  property bool valueShowText: widgetData.showText !== undefined ? widgetData.showText : widgetMetadata.showText
  property string valueHideMode: widgetData.hideMode !== undefined ? widgetData.hideMode : widgetMetadata.hideMode
  property string valueScrollingMode: widgetData.scrollingMode || widgetMetadata.scrollingMode
  property int valueMaxWidth: widgetData.maxWidth !== undefined ? widgetData.maxWidth : widgetMetadata.maxWidth
  property bool valueUseFixedWidth: widgetData.useFixedWidth !== undefined ? widgetData.useFixedWidth : widgetMetadata.useFixedWidth
  property bool valueColorizeIcons: widgetData.colorizeIcons !== undefined ? widgetData.colorizeIcons : widgetMetadata.colorizeIcons
  property string valueTextColor: widgetData.textColor !== undefined ? widgetData.textColor : widgetMetadata.textColor

  Component.onCompleted: {
    if (widgetData && widgetData.hideMode !== undefined) {
      valueHideMode = widgetData.hideMode;
    }
  }

  function saveSettings() {
    var settings = Object.assign({}, widgetData || {});
    settings.hideMode = valueHideMode;
    settings.showIcon = valueShowIcon;
    settings.showText = valueShowText;
    settings.scrollingMode = valueScrollingMode;
    settings.maxWidth = parseInt(widthInput.text) || widgetMetadata.maxWidth;
    settings.useFixedWidth = valueUseFixedWidth;
    settings.colorizeIcons = valueColorizeIcons;
    settings.textColor = valueTextColor;
    settingsChanged(settings);
  }

  NComboBox {
    Layout.fillWidth: true
    label: "Hiding mode"
    description: "Controls how the widget behaves when no window is active."
    model: [
      {
        "key": "visible",
        "name": "Always visible"
      },
      {
        "key": "hidden",
        "name": "Hide when empty"
      },
      {
        "key": "transparent",
        "name": "Transparent when empty"
      }
    ]
    currentKey: root.valueHideMode
    onSelected: key => {
                  root.valueHideMode = key;
                  saveSettings();
                }
    defaultValue: widgetMetadata.hideMode
  }

  NColorChoice {
    label: "Select color"
    currentKey: valueTextColor
    onSelected: key => {
                  valueTextColor = key;
                  saveSettings();
                }
    defaultValue: widgetMetadata.textColor
  }

  NToggle {
    Layout.fillWidth: true
    label: "Show window title"
    description: "Display the window title."
    checked: root.valueShowText
    onToggled: checked => {
                 root.valueShowText = checked;
                 saveSettings();
               }
    defaultValue: widgetMetadata.showText
  }

  NToggle {
    Layout.fillWidth: true
    label: "Show app icon"
    description: "Display the application icon next to the window title."
    checked: root.valueShowIcon
    onToggled: checked => {
                 root.valueShowIcon = checked;
                 saveSettings();
               }
    defaultValue: widgetMetadata.showIcon
  }

  NToggle {
    Layout.fillWidth: true
    label: "Colorize icons"
    description: "Apply theme colors to active window icon."
    checked: root.valueColorizeIcons
    onToggled: checked => {
                 root.valueColorizeIcons = checked;
                 saveSettings();
               }
    visible: root.valueShowIcon
    defaultValue: widgetMetadata.colorizeIcons
  }

  NTextInput {
    id: widthInput
    Layout.fillWidth: true
    label: "Maximum width"
    description: "Sets the maximum horizontal size of the widget. The widget will shrink to fit shorter content."
    placeholderText: widgetMetadata.maxWidth
    text: valueMaxWidth
    onTextChanged: saveSettings()
    defaultValue: String(widgetMetadata.maxWidth)
  }

  NToggle {
    Layout.fillWidth: true
    label: "Use fixed width"
    description: "When enabled, the widget will always use the maximum width instead of dynamically adjusting to content."
    checked: valueUseFixedWidth
    onToggled: checked => {
                 valueUseFixedWidth = checked;
                 saveSettings();
               }
    defaultValue: widgetMetadata.useFixedWidth
  }

  NComboBox {
    label: "Scrolling mode"
    description: "Control when text scrolling is enabled for long window titles."
    model: [
      {
        "key": "always",
        "name": "Scroll always"
      },
      {
        "key": "hover",
        "name": "Scroll on hover"
      },
      {
        "key": "never",
        "name": "Never scroll"
      }
    ]
    currentKey: valueScrollingMode
    defaultValue: widgetMetadata.scrollingMode
    onSelected: key => {
                  valueScrollingMode = key;
                  saveSettings();
                }
    minimumWidth: 200
  }
}
