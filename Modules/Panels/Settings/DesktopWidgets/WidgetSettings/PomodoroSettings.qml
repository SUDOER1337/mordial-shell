import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Commons
import qs.Widgets

ColumnLayout {
  id: root

  property var widgetData: ({})
  property var metadata: ({})
  property var screen

  readonly property int workDuration: widgetData.workDuration !== undefined ? widgetData.workDuration : (metadata.workDuration !== undefined ? metadata.workDuration : 25)
  readonly property int shortBreakDuration: widgetData.shortBreakDuration !== undefined ? widgetData.shortBreakDuration : (metadata.shortBreakDuration !== undefined ? metadata.shortBreakDuration : 5)
  readonly property int longBreakDuration: widgetData.longBreakDuration !== undefined ? widgetData.longBreakDuration : (metadata.longBreakDuration !== undefined ? metadata.longBreakDuration : 15)
  readonly property int sessionsBeforeLongBreak: widgetData.sessionsBeforeLongBreak !== undefined ? widgetData.sessionsBeforeLongBreak : (metadata.sessionsBeforeLongBreak !== undefined ? metadata.sessionsBeforeLongBreak : 4)
  readonly property bool autoStartBreaks: widgetData.autoStartBreaks !== undefined ? widgetData.autoStartBreaks : (metadata.autoStartBreaks !== undefined ? metadata.autoStartBreaks : false)
  readonly property bool autoStartWork: widgetData.autoStartWork !== undefined ? widgetData.autoStartWork : (metadata.autoStartWork !== undefined ? metadata.autoStartWork : false)
  readonly property bool compactMode: widgetData.compactMode !== undefined ? widgetData.compactMode : (metadata.compactMode !== undefined ? metadata.compactMode : false)
  readonly property bool playSound: widgetData.playSound !== undefined ? widgetData.playSound : (metadata.playSound !== undefined ? metadata.playSound : true)
  readonly property real soundVolume: widgetData.soundVolume !== undefined ? widgetData.soundVolume : (metadata.soundVolume !== undefined ? metadata.soundVolume : 0.3)
  readonly property bool soundRepeat: widgetData.soundRepeat !== undefined ? widgetData.soundRepeat : (metadata.soundRepeat !== undefined ? metadata.soundRepeat : true)
  readonly property string customSoundPath: widgetData.customSoundPath !== undefined ? widgetData.customSoundPath : (metadata.customSoundPath !== undefined ? metadata.customSoundPath : "")

  function emitChange() {
    var newData = Object.assign({}, widgetData, {
                                  workDuration: workDurationInput.value,
                                  shortBreakDuration: shortBreakDurationInput.value,
                                  longBreakDuration: longBreakDurationInput.value,
                                  sessionsBeforeLongBreak: sessionsInput.value,
                                  autoStartBreaks: autoStartBreaksSwitch.checked,
                                  autoStartWork: autoStartWorkSwitch.checked,
                                  compactMode: compactModeSwitch.checked,
                                  playSound: playSoundSwitch.checked,
                                  soundVolume: soundVolumeSlider.value,
                                  soundRepeat: soundRepeatSwitch.checked,
                                  customSoundPath: customSoundPathInput.text
                                });
    widgetData = newData;
    settingsChanged(newData);
  }

  signal settingsChanged(var settings)

  spacing: Style.marginM

  NText {
    text: "Pomodoro Settings"
    pointSize: Style.fontSizeL
    font.weight: Style.fontWeightSemiBold
    color: Color.mOnSurface
  }

  GridLayout {
    columns: 2
    columnSpacing: Style.marginL
    rowSpacing: Style.marginM
    Layout.fillWidth: true

    NText {
      text: "Work Duration (min)"
      color: Color.mOnSurface
      Layout.fillWidth: true
    }

    SpinBox {
      id: workDurationInput
      from: 1
      to: 120
      value: root.workDuration
      onValueChanged: root.emitChange()
      Layout.preferredWidth: 100
    }

    NText {
      text: "Short Break (min)"
      color: Color.mOnSurface
      Layout.fillWidth: true
    }

    SpinBox {
      id: shortBreakDurationInput
      from: 1
      to: 60
      value: root.shortBreakDuration
      onValueChanged: root.emitChange()
      Layout.preferredWidth: 100
    }

    NText {
      text: "Long Break (min)"
      color: Color.mOnSurface
      Layout.fillWidth: true
    }

    SpinBox {
      id: longBreakDurationInput
      from: 1
      to: 60
      value: root.longBreakDuration
      onValueChanged: root.emitChange()
      Layout.preferredWidth: 100
    }

    NText {
      text: "Sessions Before Long Break"
      color: Color.mOnSurface
      Layout.fillWidth: true
    }

    SpinBox {
      id: sessionsInput
      from: 1
      to: 10
      value: root.sessionsBeforeLongBreak
      onValueChanged: root.emitChange()
      Layout.preferredWidth: 100
    }
  }

  NDivider {
    Layout.fillWidth: true
  }

  ColumnLayout {
    spacing: Style.marginS
    Layout.fillWidth: true

    NSwitch {
      id: autoStartBreaksSwitch
      text: "Auto-start breaks"
      checked: root.autoStartBreaks
      onCheckedChanged: root.emitChange()
    }

    NSwitch {
      id: autoStartWorkSwitch
      text: "Auto-start work"
      checked: root.autoStartWork
      onCheckedChanged: root.emitChange()
    }

    NSwitch {
      id: compactModeSwitch
      text: "Compact mode"
      checked: root.compactMode
      onCheckedChanged: root.emitChange()
    }

    NSwitch {
      id: playSoundSwitch
      text: "Play sound"
      checked: root.playSound
      onCheckedChanged: root.emitChange()
    }

    NSwitch {
      id: soundRepeatSwitch
      text: "Repeat alarm sound"
      checked: root.soundRepeat
      onCheckedChanged: root.emitChange()
    }
  }

  ColumnLayout {
    spacing: Style.marginS
    Layout.fillWidth: true
    visible: playSoundSwitch.checked

    NText {
      text: "Sound Volume: " + Math.round(soundVolumeSlider.value * 100) + "%"
      color: Color.mOnSurface
    }

    Slider {
      id: soundVolumeSlider
      from: 0.0
      to: 1.0
      stepSize: 0.05
      value: root.soundVolume
      onValueChanged: root.emitChange()
      Layout.fillWidth: true
    }
  }

  ColumnLayout {
    spacing: Style.marginS
    Layout.fillWidth: true

    NText {
      text: "Custom Sound Path (optional)"
      color: Color.mOnSurface
    }

    TextField {
      id: customSoundPathInput
      text: root.customSoundPath
      placeholderText: "Leave empty to use default"
      onTextChanged: root.emitChange()
      Layout.fillWidth: true
    }
  }
}
