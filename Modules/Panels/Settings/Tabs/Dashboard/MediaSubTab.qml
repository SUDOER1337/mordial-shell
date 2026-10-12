import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Widgets

// ============================================================
// MediaSubTab - appearance of the media card.
// The card itself (MediaPlayerCard) sources its art, visualizer and
// scrolling options from the MediaMini bar widget; this page owns the
// blurred album art filling the card behind that content and the frame
// drawn around the album artwork.
// ============================================================
ColumnLayout {
  id: root
  spacing: Style.marginL
  Layout.fillWidth: true
  Layout.fillHeight: true

  // Used to centre the colour picker dialog; see SettingsContent.
  property var screen

  NToggle {
    label: "Media background blur"
    description: "Blur the current track's album art into the media card background."
    checked: Settings.data.dashboard.mediaBlur.enabled
    onToggled: checked => Settings.data.dashboard.mediaBlur.enabled = checked
    defaultValue: Settings.getDefaultValue("dashboard.mediaBlur.enabled")
  }

  NValueSlider {
    Layout.fillWidth: true
    label: "Media background blur strength"
    description: "How strongly the album art is blurred behind the media card."
    from: 0.0
    to: 1.0
    stepSize: 0.01
    showReset: true
    value: Settings.data.dashboard.mediaBlur.strength
    onMoved: value => Settings.data.dashboard.mediaBlur.strength = value
    // Hidden rather than disabled when the blur is off: the card drops the
    // album art entirely in that case, so a strength value would be inert.
    visible: Settings.data.dashboard.mediaBlur.enabled
    text: (Settings.data.dashboard.mediaBlur.strength * 100).toFixed(0) + "%"
    defaultValue: Settings.getDefaultValue("dashboard.mediaBlur.strength")
  }

  NDivider {
    Layout.fillWidth: true
  }

  NValueSlider {
    Layout.fillWidth: true
    label: "Album art frame width"
    description: "Draw a frame around the album artwork. Set to 0 for no frame."
    from: 0
    to: 12
    stepSize: 1
    showReset: true
    value: Settings.data.dashboard.mediaCard.frameWidth
    onMoved: value => Settings.data.dashboard.mediaCard.frameWidth = value
    text: Settings.data.dashboard.mediaCard.frameWidth + " px"
    defaultValue: Settings.getDefaultValue("dashboard.mediaCard.frameWidth")
  }

  RowLayout {
    Layout.fillWidth: true
    // A width of 0 draws no frame, so the colour would have nothing to tint.
    visible: Settings.data.dashboard.mediaCard.frameWidth > 0

    NLabel {
      label: "Album art frame color"
      description: "Color of the frame drawn around the album artwork."
      Layout.alignment: Qt.AlignTop
    }

    NColorPicker {
      screen: root.screen
      selectedColor: Settings.data.dashboard.mediaCard.frameColor
      onColorSelected: color => Settings.data.dashboard.mediaCard.frameColor = color
    }
  }

  Rectangle {
    Layout.fillHeight: true
  }
}
