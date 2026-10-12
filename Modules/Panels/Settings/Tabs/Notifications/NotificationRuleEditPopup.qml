import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Commons
import qs.Services.System
import qs.Widgets

Popup {
  id: root
  modal: true
  closePolicy: Popup.NoAutoClose
  dim: true
  anchors.centerIn: parent

  width: Math.min(500 * Style.uiScaleRatio, parent.width * 0.9)
  padding: Style.marginL

  property int editIndex: -1
  property string patternValue: ""
  property string actionValue: "block"

  signal saved(string pattern, string action)

  property var _savedSlot: null
  property string _selectedAction: "block"

  background: Rectangle {
    color: Color.mSurface
    radius: Style.radiusL
    border.color: Color.mOutline
    border.width: Style.borderS
  }

  onOpened: {
    patternInput.text = patternValue;
    actionCombo.currentKey = actionValue;
    _selectedAction = actionValue;
    patternInput.forceActiveFocus();
  }

  contentItem: ColumnLayout {
    id: contentLayout
    spacing: Style.marginL

    RowLayout {
      Layout.fillWidth: true
      NText {
        text: editIndex >= 0 ? "Edit rule" : "Add rule"
        font.weight: Style.fontWeightBold
        pointSize: Style.fontSizeL
        Layout.fillWidth: true
      }
      NIconButton {
        icon: "close"
        onClicked: root.close()
      }
    }

    ColumnLayout {
      Layout.fillWidth: true
      spacing: Style.marginM

      NTextInput {
        id: patternInput
        Layout.fillWidth: true
        label: "Pattern"
        placeholderText: "firefox, discord, or /regex/"
        fontFamily: Settings.data.ui.fontFixed
      }

      NComboBox {
        id: actionCombo
        Layout.fillWidth: true
        label: "Action"
        model: [
          {
            "key": "block",
            "name": "Block"
          },
          {
            "key": "mute",
            "name": "Mute"
          },
          {
            "key": "hide",
            "name": "Hide"
          }
        ]
        currentKey: actionValue
        onSelected: key => {
                      actionValue = key;
                      _selectedAction = key;
                    }
      }

      NLabel {
        Layout.fillWidth: true
        label: _selectedAction === "block" ? "Skips completely." : (_selectedAction === "mute" ? "No sound, still shows popup and in history." : "No popup, no sound, adds to history.")
        labelColor: Color.mOnSurfaceVariant
      }
    }

    RowLayout {
      Layout.fillWidth: true
      spacing: Style.marginM

      Item {
        Layout.fillWidth: true
      }

      NButton {
        text: "Cancel"
        outlined: true
        onClicked: root.close()
      }

      NButton {
        text: "Save"
        icon: "check"
        backgroundColor: Color.mPrimary
        textColor: Color.mOnPrimary
        enabled: patternInput.text.trim() !== ""
        onClicked: {
          root.saved(patternInput.text.trim(), _selectedAction || "block");
          root.close();
        }
      }
    }
  }
}
