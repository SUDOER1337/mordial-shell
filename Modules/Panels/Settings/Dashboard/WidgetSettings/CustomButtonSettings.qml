import QtQml.Models
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Commons
import qs.Widgets

ColumnLayout {
  id: root
  spacing: Style.marginM
  Layout.preferredWidth: Math.round(600 * Style.uiScaleRatio)
  implicitWidth: Layout.preferredWidth

  property var widgetData: null
  property var widgetMetadata: null
  property var rootSettings: null

  signal settingsChanged(var settings)

  QtObject {
    id: _settings

    property string icon: widgetData.icon !== undefined ? widgetData.icon : widgetMetadata.icon
    property string onClicked: widgetData.onClicked !== undefined ? widgetData.onClicked : widgetMetadata.onClicked
    property string onRightClicked: widgetData.onRightClicked !== undefined ? widgetData.onRightClicked : widgetMetadata.onRightClicked
    property string onMiddleClicked: widgetData.onMiddleClicked !== undefined ? widgetData.onMiddleClicked : widgetMetadata.onMiddleClicked
    property ListModel _stateChecksListModel: ListModel {}
    property string stateChecksJson: "[]"
    property string generalTooltipText: widgetData.generalTooltipText !== undefined ? widgetData.generalTooltipText : widgetMetadata.generalTooltipText
    property bool enableOnStateLogic: widgetData.enableOnStateLogic !== undefined ? widgetData.enableOnStateLogic : widgetMetadata.enableOnStateLogic
    property bool showExecTooltip: widgetData.showExecTooltip !== undefined ? widgetData.showExecTooltip : widgetMetadata.showExecTooltip

    function populateStateChecks() {
      try {
        var initialChecks = JSON.parse(stateChecksJson);
        if (initialChecks && Array.isArray(initialChecks)) {
          for (var i = 0; i < initialChecks.length; i++) {
            var item = initialChecks[i];
            if (item && typeof item === "object") {
              _settings._stateChecksListModel.append({
                                                       "command": item.command || "",
                                                       "icon": item.icon || ""
                                                     });
            } else {
              Logger.w("CustomButtonSettings", "Invalid stateChecks entry at index " + i + ":", item);
            }
          }
        }
      } catch (e) {
        Logger.e("CustomButtonSettings", "Failed to parse stateChecksJson:", e.message);
      }
    }

    Component.onCompleted: {
      root.rootSettings = _settings;
      stateChecksJson = (widgetData && widgetData.stateChecksJson !== undefined) ? widgetData.stateChecksJson : (widgetMetadata && widgetMetadata.stateChecksJson ? widgetMetadata.stateChecksJson : "[]");
      Qt.callLater(populateStateChecks);
    }

    function saveSettings() {
      var savedStateChecksArray = [];
      for (var i = 0; i < _settings._stateChecksListModel.count; i++) {
        savedStateChecksArray.push(_settings._stateChecksListModel.get(i));
      }
      _settings.stateChecksJson = JSON.stringify(savedStateChecksArray);

      return {
        "id": widgetData.id,
        "icon": _settings.icon,
        "onClicked": _settings.onClicked,
        "onRightClicked": _settings.onRightClicked,
        "onMiddleClicked": _settings.onMiddleClicked,
        "stateChecksJson": _settings.stateChecksJson,
        "generalTooltipText": _settings.generalTooltipText,
        "enableOnStateLogic": _settings.enableOnStateLogic,
        "showExecTooltip": _settings.showExecTooltip
      };
    }
  }

  function saveSettings() {
    return _settings.saveSettings();
  }

  function updateStateCheck(index, command, icon) {
    _settings._stateChecksListModel.set(index, {
                                          "command": command,
                                          "icon": icon
                                        });
    _settings.saveSettings();
  }

  function removeStateCheck(index) {
    _settings._stateChecksListModel.remove(index);
    _settings.saveSettings();
  }

  function addStateCheck() {
    _settings._stateChecksListModel.append({
                                             "command": "",
                                             "icon": ""
                                           });
    _settings.saveSettings();
  }

  RowLayout {
    spacing: Style?.marginM ?? 8

    NLabel {
      label: "Icon"
      description: "Select an icon from the library."
    }

    NIcon {
      Layout.alignment: Qt.AlignVCenter
      icon: _settings.icon || (widgetMetadata && widgetMetadata.icon ? widgetMetadata.icon : "")
      pointSize: Style?.fontSizeXL ?? 24
      visible: (_settings.icon || (widgetMetadata && widgetMetadata.icon ? widgetMetadata.icon : "")) !== ""
    }

    NButton {
      text: "Browse"
      onClicked: iconPicker.open()
    }
  }

  NIconPicker {
    id: iconPicker
    initialIcon: _settings.icon
    onIconSelected: function (iconName) {
      _settings.icon = iconName;
      saveSettings();
    }
  }

  NTextInput {
    Layout.fillWidth: true
    label: "Custom tooltip text"
    description: "Custom text to display in the button's tooltip."
    placeholderText: "Enter tooltip"
    text: _settings.generalTooltipText
    onTextChanged: {
      _settings.generalTooltipText = text;
      saveSettings();
    }
    defaultValue: widgetMetadata.generalTooltipText
  }

  NToggle {
    Layout.fillWidth: true
    label: "Show command tooltips"
    description: "Show tooltips with command details (left/right/middle click, wheel)."
    checked: _settings.showExecTooltip
    onToggled: checked => {
                 _settings.showExecTooltip = checked;
                 saveSettings();
               }
    defaultValue: widgetMetadata.showExecTooltip
  }

  NTextInput {
    Layout.fillWidth: true
    label: "Left click"
    description: "Command to execute when the button is left-clicked."
    placeholderText: "Enter command to execute (app or custom script)"
    text: _settings.onClicked
    onTextChanged: {
      _settings.onClicked = text;
      saveSettings();
    }
    defaultValue: widgetMetadata.onClicked
  }

  NTextInput {
    Layout.fillWidth: true
    label: "Right click"
    description: "Command to execute when the button is right-clicked."
    placeholderText: "Enter command to execute (app or custom script)"
    text: _settings.onRightClicked
    onTextChanged: {
      _settings.onRightClicked = text;
      saveSettings();
    }
    defaultValue: widgetMetadata.onRightClicked
  }

  NTextInput {
    Layout.fillWidth: true
    label: "Middle click"
    description: "Command to execute when the button is middle-clicked."
    placeholderText: "Enter command to execute (app or custom script)"
    text: _settings.onMiddleClicked
    onTextChanged: {
      _settings.onMiddleClicked = text;
      saveSettings();
    }
    defaultValue: widgetMetadata.onMiddleClicked
  }

  NDivider {}

  NToggle {
    id: enableOnStateLogicToggle
    Layout.fillWidth: true
    label: "Enable on-state logic"
    description: "Enable a second icon and 'hot' state based on a check command."
    checked: _settings.enableOnStateLogic
    onToggled: checked => {
                 _settings.enableOnStateLogic = checked;
                 saveSettings();
               }
    defaultValue: widgetMetadata.enableOnStateLogic
  }

  ColumnLayout {
    Layout.fillWidth: true
    visible: root.rootSettings && root.rootSettings.enableOnStateLogic
    spacing: Style?.marginM ?? 8

    NLabel {
      label: "State checks"
    }

    Repeater {
      model: root.rootSettings ? root.rootSettings._stateChecksListModel : null
      delegate: Item {
        property int currentIndex: index

        implicitHeight: contentRow.implicitHeight
        Layout.fillWidth: true

        RowLayout {
          id: contentRow
          anchors.fill: parent
          spacing: Style?.marginM ?? 8

          NTextInput {
            Layout.fillWidth: true
            placeholderText: "Command to execute for this state check"
            text: model.command
            onTextChanged: {
              updateStateCheck(currentIndex, text, model.icon);
            }
          }

          RowLayout {
            Layout.alignment: Qt.AlignVCenter
            spacing: Style?.marginS ?? 4

            NIcon {
              icon: model.icon
              pointSize: Style?.fontSizeL ?? 20
              visible: model.icon !== undefined && model.icon !== ""
            }

            NIconButton {
              icon: "folder"
              tooltipText: "Browse"
              baseSize: Style?.buttonSizeS ?? 24
              onClicked: iconPickerDelegate.open()
            }

            NIconButton {
              icon: "close"
              tooltipText: "Remove"
              baseSize: Style?.buttonSizeS ?? 24
              colorBorder: Qt.alpha(Color.mOutline, Style.opacityLight)
              colorBg: Color.mError
              colorFg: Color.mOnError
              colorBgHover: Qt.alpha(Color.mError, Style.opacityMedium)
              colorFgHover: Color.mOnError
              onClicked: {
                removeStateCheck(currentIndex);
              }
            }
          }
        }

        NIconPicker {
          id: iconPickerDelegate
          initialIcon: model.icon
          onIconSelected: function (iconName) {
            updateStateCheck(currentIndex, model.command, iconName);
          }
        }
      }
    }

    Item {
      Layout.fillWidth: true
    }

    RowLayout {
      Layout.fillWidth: true
      spacing: Style?.marginM ?? 8

      NButton {
        text: "Add state check"
        onClicked: addStateCheck()
      }
    }
  }
}
