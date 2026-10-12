import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window
import qs.Commons
import qs.Services.UI
import qs.Widgets

ColumnLayout {
  id: root
  spacing: Style.marginM

  // Properties to receive data from parent
  property var screen: null
  property var widgetData: null
  property var widgetMetadata: null

  signal settingsChanged(var settings)

  // Bar orientation (per-screen)
  property bool barIsVertical: (Settings.getBarPositionForScreen(screen?.name) === "left" || Settings.getBarPositionForScreen(screen?.name) === "right")

  property string valueIcon: widgetData.icon !== undefined ? widgetData.icon : widgetMetadata.icon
  property string valueIconPosition: widgetData.iconPosition !== undefined ? widgetData.iconPosition : widgetMetadata.iconPosition
  property bool valueTextStream: widgetData.textStream !== undefined ? widgetData.textStream : widgetMetadata.textStream
  property bool valueParseJson: widgetData.parseJson !== undefined ? widgetData.parseJson : widgetMetadata.parseJson
  property int valueMaxTextLengthHorizontal: widgetData?.maxTextLength?.horizontal ?? widgetMetadata?.maxTextLength?.horizontal
  property int valueMaxTextLengthVertical: widgetData?.maxTextLength?.vertical ?? widgetMetadata?.maxTextLength?.vertical
  property string valueHideMode: (widgetData.hideMode !== undefined) ? widgetData.hideMode : widgetMetadata.hideMode
  property bool valueShowIcon: (widgetData.showIcon !== undefined) ? widgetData.showIcon : widgetMetadata.showIcon
  property bool valueShowExecTooltip: widgetData.showExecTooltip !== undefined ? widgetData.showExecTooltip : widgetMetadata.showExecTooltip
  property bool valueShowTextTooltip: widgetData.showTextTooltip !== undefined ? widgetData.showTextTooltip : widgetMetadata.showTextTooltip
  property string valueColorizeSystemIcon: widgetData.colorizeSystemIcon !== undefined ? widgetData.colorizeSystemIcon : widgetMetadata.colorizeSystemIcon
  property string valueColorizeSystemText: widgetData.colorizeSystemText !== undefined ? widgetData.colorizeSystemText : widgetMetadata.colorizeSystemText
  property string valueIpcIdentifier: widgetData.ipcIdentifier !== undefined ? widgetData.ipcIdentifier : widgetMetadata.ipcIdentifier
  property string valueGeneralTooltipText: widgetData.generalTooltipText !== undefined ? widgetData.generalTooltipText : widgetMetadata.generalTooltipText

  function saveSettings() {
    var settings = Object.assign({}, widgetData || {});
    settings.icon = valueIcon;
    settings.iconPosition = valueIconPosition;
    settings.leftClickExec = leftClickExecInput.text;
    settings.leftClickUpdateText = leftClickUpdateText.checked;
    settings.rightClickExec = rightClickExecInput.text;
    settings.rightClickUpdateText = rightClickUpdateText.checked;
    settings.middleClickExec = middleClickExecInput.text;
    settings.middleClickUpdateText = middleClickUpdateText.checked;
    settings.wheelMode = separateWheelToggle.internalChecked ? "separate" : "unified";
    settings.wheelExec = wheelExecInput.text;
    settings.wheelUpExec = wheelUpExecInput.text;
    settings.wheelDownExec = wheelDownExecInput.text;
    settings.wheelUpdateText = wheelUpdateText.checked;
    settings.wheelUpUpdateText = wheelUpUpdateText.checked;
    settings.wheelDownUpdateText = wheelDownUpdateText.checked;
    settings.textCommand = textCommandInput.text;
    settings.textCollapse = textCollapseInput.text;
    settings.textStream = valueTextStream;
    settings.parseJson = valueParseJson;
    settings.showIcon = valueShowIcon;
    settings.showExecTooltip = valueShowExecTooltip;
    settings.showTextTooltip = valueShowTextTooltip;
    settings.hideMode = valueHideMode;
    settings.maxTextLength = {
      "horizontal": valueMaxTextLengthHorizontal,
      "vertical": valueMaxTextLengthVertical
    };
    settings.textIntervalMs = parseInt(textIntervalInput.text || textIntervalInput.placeholderText, 10);
    settings.colorizeSystemIcon = valueColorizeSystemIcon;
    settings.colorizeSystemText = valueColorizeSystemText;
    settings.ipcIdentifier = valueIpcIdentifier;
    settings.generalTooltipText = valueGeneralTooltipText;
    settingsChanged(settings);
  }

  NTabBar {
    id: subTabBar
    Layout.fillWidth: true
    Layout.bottomMargin: Style.marginM
    distributeEvenly: true
    currentIndex: tabView.currentIndex

    NTabButton {
      text: "Actions"
      tabIndex: 0
      checked: tabView.currentIndex === 0
      onClicked: tabView.currentIndex = 0
    }
    NTabButton {
      text: "Icon"
      tabIndex: 1
      checked: tabView.currentIndex === 1
      onClicked: tabView.currentIndex = 1
    }
    NTabButton {
      text: "Text Command"
      tabIndex: 2
      checked: tabView.currentIndex === 2
      onClicked: tabView.currentIndex = 2
    }
  }

  NTabView {
    id: tabView
    Layout.fillWidth: true

    // ============ Actions Tab ============
    ColumnLayout {
      spacing: Style.marginM

      RowLayout {
        spacing: Style.marginM

        NTextInput {
          id: leftClickExecInput
          Layout.fillWidth: true
          label: "Left click"
          description: "Command to execute when the button is left-clicked."
          placeholderText: "Enter command to execute (app or custom script)"
          text: widgetData?.leftClickExec || widgetMetadata.leftClickExec
          onTextChanged: saveSettings()
          defaultValue: widgetMetadata.leftClickExec
        }

        NToggle {
          id: leftClickUpdateText
          enabled: !valueTextStream
          Layout.alignment: Qt.AlignRight | Qt.AlignBottom
          Layout.bottomMargin: Style.marginS
          onEntered: TooltipService.show(leftClickUpdateText, "Update displayed text on left-click")
          onExited: TooltipService.hide()
          checked: widgetData?.leftClickUpdateText ?? widgetMetadata.leftClickUpdateText
          onToggled: isChecked => {
                       checked = isChecked;
                       saveSettings();
                     }
          defaultValue: widgetMetadata.leftClickUpdateText
        }
      }

      RowLayout {
        spacing: Style.marginM

        NTextInput {
          id: rightClickExecInput
          Layout.fillWidth: true
          label: "Right click"
          description: "Command to execute when the button is right-clicked."
          placeholderText: "Enter command to execute (app or custom script)"
          text: widgetData?.rightClickExec || widgetMetadata.rightClickExec
          onTextChanged: saveSettings()
          defaultValue: widgetMetadata.rightClickExec
        }

        NToggle {
          id: rightClickUpdateText
          enabled: !valueTextStream
          Layout.alignment: Qt.AlignRight | Qt.AlignBottom
          Layout.bottomMargin: Style.marginS
          onEntered: TooltipService.show(rightClickUpdateText, "Update displayed text on right-click")
          onExited: TooltipService.hide()
          checked: widgetData?.rightClickUpdateText ?? widgetMetadata.rightClickUpdateText
          onToggled: isChecked => {
                       checked = isChecked;
                       saveSettings();
                     }
          defaultValue: widgetMetadata.rightClickUpdateText
        }
      }

      RowLayout {
        spacing: Style.marginM

        NTextInput {
          id: middleClickExecInput
          Layout.fillWidth: true
          label: "Middle click"
          description: "Command to execute when the button is middle-clicked."
          placeholderText: "Enter command to execute (app or custom script)"
          text: widgetData?.middleClickExec || widgetMetadata.middleClickExec
          onTextChanged: saveSettings()
          defaultValue: widgetMetadata.middleClickExec
        }

        NToggle {
          id: middleClickUpdateText
          enabled: !valueTextStream
          Layout.alignment: Qt.AlignRight | Qt.AlignBottom
          Layout.bottomMargin: Style.marginS
          onEntered: TooltipService.show(middleClickUpdateText, "Update displayed text on middle-click")
          onExited: TooltipService.hide()
          checked: widgetData?.middleClickUpdateText ?? widgetMetadata.middleClickUpdateText
          onToggled: isChecked => {
                       checked = isChecked;
                       saveSettings();
                     }
          defaultValue: widgetMetadata.middleClickUpdateText
        }
      }

      NToggle {
        id: separateWheelToggle
        Layout.fillWidth: true
        label: "Separate wheel commands"
        description: "Enable separate commands for wheel up and down."
        property bool internalChecked: (widgetData?.wheelMode || widgetMetadata?.wheelMode) === "separate"
        checked: internalChecked
        onToggled: checked => {
                     internalChecked = checked;
                     saveSettings();
                   }
        defaultValue: widgetMetadata.wheelMode === "separate"
      }

      ColumnLayout {
        Layout.fillWidth: true

        RowLayout {
          id: unifiedWheelLayout
          visible: !separateWheelToggle.checked
          spacing: Style.marginM

          NTextInput {
            id: wheelExecInput
            Layout.fillWidth: true
            label: "Scroll wheel"
            description: "Command to execute when the scroll wheel is used.<br>Use $delta for the scroll wheel delta in the command."
            placeholderText: "Enter command to execute (app or custom script)"
            text: widgetData?.wheelExec || widgetMetadata?.wheelExec
            onTextChanged: saveSettings()
            defaultValue: widgetMetadata.wheelExec
          }

          NToggle {
            id: wheelUpdateText
            enabled: !valueTextStream
            Layout.alignment: Qt.AlignRight | Qt.AlignBottom
            Layout.bottomMargin: Style.marginS
            onEntered: TooltipService.show(wheelUpdateText, "Update displayed text on scroll")
            onExited: TooltipService.hide()
            checked: widgetData?.wheelUpdateText ?? widgetMetadata?.wheelUpdateText
            onToggled: isChecked => {
                         checked = isChecked;
                         saveSettings();
                       }
            defaultValue: widgetMetadata.wheelUpdateText
          }
        }

        ColumnLayout {
          id: separatedWheelLayout
          Layout.fillWidth: true
          visible: separateWheelToggle.checked

          RowLayout {
            spacing: Style.marginM

            NTextInput {
              id: wheelUpExecInput
              Layout.fillWidth: true
              label: "Wheel up command"
              description: "Command to execute when the scroll wheel is scrolled up."
              placeholderText: "Enter command to execute (app or custom script)"
              text: widgetData?.wheelUpExec || widgetMetadata?.wheelUpExec
              onTextChanged: saveSettings()
              defaultValue: widgetMetadata.wheelUpExec
            }

            NToggle {
              id: wheelUpUpdateText
              enabled: !valueTextStream
              Layout.alignment: Qt.AlignRight | Qt.AlignBottom
              Layout.bottomMargin: Style.marginS
              onEntered: TooltipService.show(wheelUpUpdateText, "Update displayed text on scroll")
              onExited: TooltipService.hide()
              checked: widgetData?.wheelUpUpdateText ?? widgetMetadata?.wheelUpUpdateText
              onToggled: isChecked => {
                           checked = isChecked;
                           saveSettings();
                         }
              defaultValue: widgetMetadata.wheelUpUpdateText
            }
          }

          RowLayout {
            spacing: Style.marginM

            NTextInput {
              id: wheelDownExecInput
              Layout.fillWidth: true
              label: "Wheel down command"
              description: "Command to execute when the scroll wheel is scrolled down."
              placeholderText: "Enter command to execute (app or custom script)"
              text: widgetData?.wheelDownExec || widgetMetadata?.wheelDownExec
              onTextChanged: saveSettings()
              defaultValue: widgetMetadata.wheelDownExec
            }

            NToggle {
              id: wheelDownUpdateText
              enabled: !valueTextStream
              Layout.alignment: Qt.AlignRight | Qt.AlignBottom
              Layout.bottomMargin: Style.marginS
              onEntered: TooltipService.show(wheelDownUpdateText, "Update displayed text on scroll")
              onExited: TooltipService.hide()
              checked: widgetData?.wheelDownUpdateText ?? widgetMetadata?.wheelDownUpdateText
              onToggled: isChecked => {
                           checked = isChecked;
                           saveSettings();
                         }
              defaultValue: widgetMetadata.wheelDownUpdateText
            }
          }
        }
      }
    }

    // ============ Icon Tab ============
    ColumnLayout {
      spacing: Style.marginM

      NToggle {
        id: showIconToggle
        label: "Show icon"
        description: "Toggles the visibility of the widget's icon."
        checked: valueShowIcon
        onToggled: checked => {
                     valueShowIcon = checked;
                     saveSettings();
                   }
        visible: textCommandInput.text !== ""
        defaultValue: widgetMetadata.showIcon
      }

      RowLayout {
        spacing: Style.marginM
        visible: valueShowIcon

        NLabel {
          label: "Icon"
          description: "Select an icon from the library."
        }

        NIcon {
          Layout.alignment: Qt.AlignVCenter
          icon: valueIcon
          pointSize: Style.fontSizeXL
          visible: valueIcon !== ""
        }

        NButton {
          text: "Browse"
          onClicked: iconPicker.open()
        }
      }

      NIconPicker {
        id: iconPicker
        initialIcon: valueIcon
        onIconSelected: function (iconName) {
          valueIcon = iconName;
          saveSettings();
        }
      }

      NComboBox {
        id: iconPositionComboBox
        visible: valueShowIcon
        label: "Icon position"
        description: "Select where the icon appears relative to the text."
        model: barIsVertical ? [
                                 {
                                   name: "Top",
                                   key: "left"
                                 },
                                 {
                                   name: "Bottom",
                                   key: "right"
                                 }
                               ] : [
                                 {
                                   name: "Left",
                                   key: "left"
                                 },
                                 {
                                   name: "Right",
                                   key: "right"
                                 }
                               ]
        currentKey: valueIconPosition
        onSelected: key => {
                      valueIconPosition = key;
                      saveSettings();
                    }
        defaultValue: widgetMetadata.iconPosition
      }

      NColorChoice {
        label: "Select icon color"
        description: "Apply theme colors to icons."
        currentKey: valueColorizeSystemIcon
        onSelected: key => {
                      valueColorizeSystemIcon = key;
                      saveSettings();
                    }
        defaultValue: widgetMetadata.colorizeSystemIcon
      }

      NTextInput {
        Layout.fillWidth: true
        label: "Custom tooltip text"
        description: "Custom text to display in the button's tooltip."
        placeholderText: "Enter tooltip"
        text: valueGeneralTooltipText
        onTextChanged: {
          valueGeneralTooltipText = text;
          saveSettings();
        }
        defaultValue: widgetMetadata.generalTooltipText
      }

      NToggle {
        id: showExecTooltipToggle
        label: "Show command tooltips"
        description: "Show tooltips with command details (left/right/middle click, wheel)."
        checked: valueShowExecTooltip
        onToggled: checked => {
                     valueShowExecTooltip = checked;
                     saveSettings();
                   }
        defaultValue: widgetMetadata.showExecTooltip
      }

      NToggle {
        id: showTextTooltipToggle
        label: "Show dynamic text tooltips"
        description: "Show tooltips with the output from the text command."
        checked: valueShowTextTooltip
        onToggled: checked => {
                     valueShowTextTooltip = checked;
                     saveSettings();
                   }
        defaultValue: widgetMetadata.showTextTooltip
      }

      NTextInput {
        Layout.fillWidth: true
        label: "IPC Identifier"
        description: "Unique identifier for IPC commands. Use this identifier with 'qs -c mordial-shell ipc call cb [action] [identifier]' to control this button via IPC."
        placeholderText: "Enter unique identifier for IPC commands"
        text: valueIpcIdentifier
        onTextChanged: {
          valueIpcIdentifier = text;
          saveSettings();
        }
        defaultValue: widgetMetadata.ipcIdentifier
      }
    }

    // ============ Text Tab ============
    ColumnLayout {
      spacing: Style.marginM

      NColorChoice {
        label: "Select text color"
        description: "Apply theme colors to text."
        currentKey: valueColorizeSystemText
        onSelected: key => {
                      valueColorizeSystemText = key;
                      saveSettings();
                    }
        defaultValue: widgetMetadata.colorizeSystemText
      }

      NSpinBox {
        label: "Max text length (horizontal)"
        description: "Maximum number of characters to show in horizontal bar (0 to hide text)."
        from: 0
        to: 100
        value: valueMaxTextLengthHorizontal
        onValueChanged: {
          valueMaxTextLengthHorizontal = value;
          saveSettings();
        }
        defaultValue: widgetMetadata.maxTextLength.horizontal
      }

      NSpinBox {
        label: "Max text length (vertical)"
        description: "Maximum number of characters to show in vertical bar (0 to hide text)."
        from: 0
        to: 100
        value: valueMaxTextLengthVertical
        onValueChanged: {
          valueMaxTextLengthVertical = value;
          saveSettings();
        }
        defaultValue: widgetMetadata.maxTextLength.vertical
      }

      NToggle {
        id: textStreamInput
        label: "Stream"
        description: "Streamed lines from the command will be displayed as text on the button."
        checked: valueTextStream
        onToggled: checked => {
                     valueTextStream = checked;
                     saveSettings();
                   }
        defaultValue: widgetMetadata.textStream
      }

      NToggle {
        id: parseJsonInput
        label: "Parse output as JSON"
        description: "Parse the command output as a JSON object to dynamically set text and icon."
        checked: valueParseJson
        onToggled: checked => {
                     valueParseJson = checked;
                     saveSettings();
                   }
        defaultValue: widgetMetadata.parseJson
      }

      NTextInput {
        id: textCommandInput
        Layout.fillWidth: true
        label: "Display command output"
        description: valueTextStream ? "Enter a command to run continuously." : "Enter a command to run at a regular interval. The first line of its output will be displayed as text."
        placeholderText: "echo \"Hello World\""
        text: widgetData?.textCommand || widgetMetadata.textCommand
        onTextChanged: saveSettings()
        defaultValue: widgetMetadata.textCommand
      }

      NTextInput {
        id: textCollapseInput
        Layout.fillWidth: true
        visible: valueTextStream
        label: "Collapse condition"
        description: "If the output text matches this value, the button will collapse."
        placeholderText: "e.g. 'nothing is playing'. Use /regex/ for patterns."
        text: widgetData?.textCollapse || widgetMetadata.textCollapse
        onTextChanged: saveSettings()
        defaultValue: widgetMetadata.textCollapse
      }

      NTextInput {
        id: textIntervalInput
        Layout.fillWidth: true
        visible: !valueTextStream
        label: "Refresh interval"
        description: "Interval in milliseconds."
        placeholderText: String(widgetMetadata.textIntervalMs)
        text: widgetData && widgetData.textIntervalMs !== undefined ? String(widgetData.textIntervalMs) : ""
        onTextChanged: saveSettings()
        defaultValue: String(widgetMetadata.textIntervalMs)
      }

      NComboBox {
        id: hideModeComboBox
        label: "Hide mode"
        description: "Controls widget visibility when the command has no output."
        model: [
          {
            name: "Always expanded",
            key: "alwaysExpanded"
          },
          {
            name: "Expand when has output",
            key: "expandWithOutput"
          },
          {
            name: "Max expanded but transparent",
            key: "maxTransparent"
          }
        ]
        currentKey: valueHideMode
        onSelected: key => {
                      valueHideMode = key;
                      saveSettings();
                    }
        visible: textCommandInput.text !== "" && valueTextStream == true
        defaultValue: widgetMetadata.hideMode
      }
    }
  }
}
