import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Commons
import qs.Services.Power
import qs.Widgets

ColumnLayout {
  id: root
  spacing: Style.marginL
  Layout.fillWidth: true

  // Master enable
  NToggle {
    Layout.fillWidth: true
    label: "Enable idle management"
    description: "Automatically turn off the screen, lock, or suspend after a period of inactivity."
    checked: Settings.data.idle.enabled
    defaultValue: Settings.getDefaultValue("idle.enabled")
    onToggled: checked => Settings.data.idle.enabled = checked
  }

  // Live idle status
  RowLayout {
    Layout.fillWidth: true
    enabled: Settings.data.idle.enabled
    visible: IdleService.nativeIdleMonitorAvailable

    NLabel {
      label: "Idle time"
      description: "Idle time as reported by the compositor."
    }

    Item {
      Layout.fillWidth: true
    }

    NText {
      Layout.alignment: Qt.AlignBottom | Qt.AlignRight
      text: IdleService.idleSeconds > 0 ? IdleService.idleSeconds + (IdleService.idleSeconds === 1 ? " second" : " seconds") : "Active"
      family: Settings.data.ui.fontFixed
      pointSize: Style.fontSizeM
      color: IdleService.idleSeconds > 0 ? Color.mPrimary : Color.mOnSurfaceVariant
    }
  }

  NLabel {
    visible: !IdleService.nativeIdleMonitorAvailable
    description: "Native idle monitoring is not available on this compositor."
  }

  NDivider {
    Layout.fillWidth: true
  }

  IdleCommandEditPopup {
    id: editPopup
    parent: Overlay.overlay
  }

  function openEdit(actionName, cmdVal, resumeCmdVal, onSaveCmd, onSaveResume) {
    editPopup.editIndex = -1;
    editPopup.showCommand = true;
    editPopup.showTimeout = false;
    editPopup.titleText = "Edit" + " " + actionName;
    editPopup.timeoutValue = 0;
    editPopup.commandValue = cmdVal;
    editPopup.resumeCommandValue = resumeCmdVal;

    try {
      editPopup.saved.disconnect(editPopup._savedSlot);
    } catch (e) {}

    editPopup._savedSlot = function (timeout, cmd, resumeCmd, name) {
      onSaveCmd(cmd);
      onSaveResume(resumeCmd);
    };

    editPopup.saved.connect(editPopup._savedSlot);
    editPopup.open();
  }

  // Timeout spinboxes and resume commands
  ColumnLayout {
    Layout.fillWidth: true
    spacing: Style.marginL
    enabled: Settings.data.idle.enabled

    NLabel {
      label: "Timeouts"
      description: "Set to 0 to disable a stage. Timeouts are paused while Keep Awake is active."
    }

    DefaultActionRow {
      actionName: "Turn off screen"
      actionDescription: "Seconds of inactivity before monitors are turned off."
      timeoutValue: Settings.data.idle.screenOffTimeout
      defaultValue: Settings.getDefaultValue("idle.screenOffTimeout")
      command: Settings.data.idle.screenOffCommand
      resumeCommand: Settings.data.idle.resumeScreenOffCommand
      onActionTimeoutChanged: val => Settings.data.idle.screenOffTimeout = val
      onActionCommandChanged: cmd => {
                                Settings.data.idle.screenOffCommand = cmd;
                                Settings.saveImmediate();
                              }
      onActionResumeCommandChanged: cmd => {
                                      Settings.data.idle.resumeScreenOffCommand = cmd;
                                      Settings.saveImmediate();
                                    }
    }

    DefaultActionRow {
      actionName: "Lock screen"
      actionDescription: "Seconds of inactivity before the lock screen activates."
      timeoutValue: Settings.data.idle.lockTimeout
      defaultValue: Settings.getDefaultValue("idle.lockTimeout")
      command: Settings.data.idle.lockCommand
      resumeCommand: Settings.data.idle.resumeLockCommand
      onActionTimeoutChanged: val => Settings.data.idle.lockTimeout = val
      onActionCommandChanged: cmd => {
                                Settings.data.idle.lockCommand = cmd;
                                Settings.saveImmediate();
                              }
      onActionResumeCommandChanged: cmd => {
                                      Settings.data.idle.resumeLockCommand = cmd;
                                      Settings.saveImmediate();
                                    }
    }

    DefaultActionRow {
      actionName: "Suspend"
      actionDescription: "Seconds of inactivity before the system suspends."
      timeoutValue: Settings.data.idle.suspendTimeout
      defaultValue: Settings.getDefaultValue("idle.suspendTimeout")
      command: Settings.data.idle.suspendCommand
      resumeCommand: Settings.data.idle.resumeSuspendCommand
      onActionTimeoutChanged: val => Settings.data.idle.suspendTimeout = val
      onActionCommandChanged: cmd => {
                                Settings.data.idle.suspendCommand = cmd;
                                Settings.saveImmediate();
                              }
      onActionResumeCommandChanged: cmd => {
                                      Settings.data.idle.resumeSuspendCommand = cmd;
                                      Settings.saveImmediate();
                                    }
    }

    NDivider {
      Layout.fillWidth: true
    }

    NSpinBox {
      label: "Fade duration"
      description: "Seconds for the fade-to-black animation before each action fires. Any mouse movement cancels the fade."
      from: 1
      to: 60
      suffix: "s"
      value: Settings.data.idle.fadeDuration
      defaultValue: Settings.getDefaultValue("idle.fadeDuration")
      onValueChanged: Settings.data.idle.fadeDuration = value
    }
  }

  component DefaultActionRow: RowLayout {
    id: rowRoot
    Layout.fillWidth: true
    spacing: Style.marginM

    property string actionName
    property string actionDescription
    property alias timeoutValue: spinBox.value
    property int defaultValue
    property string command
    property string resumeCommand

    signal actionTimeoutChanged(int newValue)
    signal actionCommandChanged(string newCmd)
    signal actionResumeCommandChanged(string newCmd)

    NSpinBox {
      id: spinBox
      Layout.fillWidth: true
      label: rowRoot.actionName
      description: rowRoot.actionDescription
      from: 0
      to: 86400
      suffix: "s"
      defaultValue: rowRoot.defaultValue
      onValueChanged: rowRoot.actionTimeoutChanged(value)
    }

    NIconButton {
      Layout.alignment: Qt.AlignVCenter
      icon: "settings"
      tooltipText: "Edit"
      onClicked: root.openEdit(rowRoot.actionName, rowRoot.command, rowRoot.resumeCommand, rowRoot.actionCommandChanged, rowRoot.actionResumeCommandChanged)
    }
  }
}
