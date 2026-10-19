import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Commons
import qs.Widgets

// File: Modules/Panels/Settings/Bar/WidgetSettings/PomodoroSettings.qml
// Purpose: Settings dialog for the Pomodoro bar widget, covering the timer
//          options plus the bar conventions for icon/text colours.
// Functions:
//   saveSettings()  - Merge edited values into widgetData and emit settingsChanged
ColumnLayout {
  id: root
  spacing: Style.marginM

  // Properties to receive data from parent
  property var screen: null
  property var widgetData: null
  property var widgetMetadata: null

  signal settingsChanged(var settings)

  // Local state. These MUST be plain (mutable) properties: the widget controls
  // read them, and the controls' handlers write back into them before saving.
  property int valueWorkDuration: widgetData.workDuration !== undefined ? widgetData.workDuration : (widgetMetadata.workDuration !== undefined ? widgetMetadata.workDuration : 25)
  property int valueShortBreakDuration: widgetData.shortBreakDuration !== undefined ? widgetData.shortBreakDuration : (widgetMetadata.shortBreakDuration !== undefined ? widgetMetadata.shortBreakDuration : 5)
  property int valueLongBreakDuration: widgetData.longBreakDuration !== undefined ? widgetData.longBreakDuration : (widgetMetadata.longBreakDuration !== undefined ? widgetMetadata.longBreakDuration : 15)
  property int valueSessionsBeforeLongBreak: widgetData.sessionsBeforeLongBreak !== undefined ? widgetData.sessionsBeforeLongBreak : (widgetMetadata.sessionsBeforeLongBreak !== undefined ? widgetMetadata.sessionsBeforeLongBreak : 4)
  property bool valueAutoStartBreaks: widgetData.autoStartBreaks !== undefined ? widgetData.autoStartBreaks : widgetMetadata.autoStartBreaks
  property bool valueAutoStartWork: widgetData.autoStartWork !== undefined ? widgetData.autoStartWork : widgetMetadata.autoStartWork
  property bool valuePlaySound: widgetData.playSound !== undefined ? widgetData.playSound : widgetMetadata.playSound
  property real valueSoundVolume: widgetData.soundVolume !== undefined ? widgetData.soundVolume : widgetMetadata.soundVolume
  property bool valueSoundRepeat: widgetData.soundRepeat !== undefined ? widgetData.soundRepeat : widgetMetadata.soundRepeat
  property string valueCustomSoundPath: widgetData.customSoundPath !== undefined ? widgetData.customSoundPath : widgetMetadata.customSoundPath
  property string valueIconColor: widgetData.iconColor !== undefined ? widgetData.iconColor : widgetMetadata.iconColor
  property string valueTextColor: widgetData.textColor !== undefined ? widgetData.textColor : widgetMetadata.textColor

  /** Persist the edited values.
  *  @returns The merged settings object (also emitted via settingsChanged)
  */
  function saveSettings() {
    var settings = Object.assign({}, widgetData || {});
    settings.workDuration = valueWorkDuration;
    settings.shortBreakDuration = valueShortBreakDuration;
    settings.longBreakDuration = valueLongBreakDuration;
    settings.sessionsBeforeLongBreak = valueSessionsBeforeLongBreak;
    settings.autoStartBreaks = valueAutoStartBreaks;
    settings.autoStartWork = valueAutoStartWork;
    settings.playSound = valuePlaySound;
    settings.soundVolume = valueSoundVolume;
    settings.soundRepeat = valueSoundRepeat;
    settings.customSoundPath = valueCustomSoundPath;
    settings.iconColor = valueIconColor;
    settings.textColor = valueTextColor;
    settingsChanged(settings);
    return settings;
  }

  NSpinBox {
    label: "Work duration"
    description: "Length of a focus session in minutes."
    from: 1
    to: 120
    value: valueWorkDuration
    onValueChanged: {
      valueWorkDuration = value;
      saveSettings();
    }
    defaultValue: widgetMetadata.workDuration
  }

  NSpinBox {
    label: "Short break"
    description: "Length of a short break in minutes."
    from: 1
    to: 60
    value: valueShortBreakDuration
    onValueChanged: {
      valueShortBreakDuration = value;
      saveSettings();
    }
    defaultValue: widgetMetadata.shortBreakDuration
  }

  NSpinBox {
    label: "Long break"
    description: "Length of a long break in minutes."
    from: 1
    to: 60
    value: valueLongBreakDuration
    onValueChanged: {
      valueLongBreakDuration = value;
      saveSettings();
    }
    defaultValue: widgetMetadata.longBreakDuration
  }

  NSpinBox {
    label: "Sessions before long break"
    description: "How many focus sessions before a long break."
    from: 1
    to: 12
    value: valueSessionsBeforeLongBreak
    onValueChanged: {
      valueSessionsBeforeLongBreak = value;
      saveSettings();
    }
    defaultValue: widgetMetadata.sessionsBeforeLongBreak
  }

  NToggle {
    label: "Auto-start breaks"
    description: "Start the break automatically when a focus session ends."
    checked: valueAutoStartBreaks
    onToggled: checked => {
                 valueAutoStartBreaks = checked;
                 saveSettings();
               }
    defaultValue: widgetMetadata.autoStartBreaks
  }

  NToggle {
    label: "Auto-start work"
    description: "Start the next focus session automatically when a break ends."
    checked: valueAutoStartWork
    onToggled: checked => {
                 valueAutoStartWork = checked;
                 saveSettings();
               }
    defaultValue: widgetMetadata.autoStartWork
  }

  NToggle {
    id: playSoundToggle
    label: "Play sound"
    description: "Play an alarm when a phase finishes."
    checked: valuePlaySound
    onToggled: checked => {
                 valuePlaySound = checked;
                 saveSettings();
               }
    defaultValue: widgetMetadata.playSound
  }

  NToggle {
    label: "Repeat alarm"
    description: "Keep ringing the alarm until it is stopped."
    checked: valueSoundRepeat
    onToggled: checked => {
                 valueSoundRepeat = checked;
                 saveSettings();
               }
    visible: valuePlaySound
    defaultValue: widgetMetadata.soundRepeat
  }

  NValueSlider {
    label: "Alarm volume"
    description: "Volume used when the alarm plays."
    from: 0.0
    to: 1.0
    stepSize: 0.05
    value: valueSoundVolume
    defaultValue: widgetMetadata.soundVolume
    showReset: true
    onMoved: value => {
               valueSoundVolume = value;
               saveSettings();
             }
    text: Math.round(valueSoundVolume * 100) + "%"
    visible: valuePlaySound
  }

  NTextInput {
    label: "Custom alarm sound"
    description: "Absolute path to an audio file. Leave empty for the default alarm."
    placeholderText: "Leave empty to use the default alarm"
    text: valueCustomSoundPath
    onTextChanged: {
      valueCustomSoundPath = text;
      saveSettings();
    }
    visible: valuePlaySound
    defaultValue: widgetMetadata.customSoundPath
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
    label: "Select text color"
    currentKey: valueTextColor
    onSelected: key => {
                  valueTextColor = key;
                  saveSettings();
                }
    defaultValue: widgetMetadata.textColor
  }
}
