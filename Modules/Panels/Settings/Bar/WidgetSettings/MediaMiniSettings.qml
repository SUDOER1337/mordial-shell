import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
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

  // Shared with MediaPlayerCard so the slider range and the card's own clamp can
  // never disagree. [min, max] in unscaled px.
  readonly property var albumArtSizeBounds: BarWidgetRegistry.widgetSettingBounds["MediaMini"].panelAlbumArtSize

  // Local state
  property string valueHideMode: widgetData.hideMode !== undefined ? widgetData.hideMode : widgetMetadata.hideMode
  // Deprecated: hideWhenIdle now folded into hideMode = "idle"
  property bool valueHideWhenIdle: widgetData.hideWhenIdle !== undefined ? widgetData.hideWhenIdle : widgetMetadata.hideWhenIdle
  property bool valueShowAlbumArt: widgetData.showAlbumArt !== undefined ? widgetData.showAlbumArt : widgetMetadata.showAlbumArt
  property bool valuePanelShowAlbumArt: widgetData.panelShowAlbumArt !== undefined ? widgetData.panelShowAlbumArt : widgetMetadata.panelShowAlbumArt
  property bool valueShowArtistFirst: widgetData.showArtistFirst !== undefined ? widgetData.showArtistFirst : widgetMetadata.showArtistFirst
  property bool valueShowTrackTitle: widgetData.showTrackTitle !== undefined ? widgetData.showTrackTitle : widgetMetadata.showTrackTitle
  property bool valueShowArtist: widgetData.showArtist !== undefined ? widgetData.showArtist : widgetMetadata.showArtist
  property bool valueShowVisualizer: widgetData.showVisualizer !== undefined ? widgetData.showVisualizer : widgetMetadata.showVisualizer
  property string valueVisualizerType: widgetData.visualizerType !== undefined ? widgetData.visualizerType : widgetMetadata.visualizerType
  property string valueScrollingMode: widgetData.scrollingMode !== undefined ? widgetData.scrollingMode : widgetMetadata.scrollingMode
  property int valueMaxWidth: widgetData.maxWidth !== undefined ? widgetData.maxWidth : widgetMetadata.maxWidth
  property bool valueUseFixedWidth: widgetData.useFixedWidth !== undefined ? widgetData.useFixedWidth : widgetMetadata.useFixedWidth
  property bool valueShowProgressRing: widgetData.showProgressRing !== undefined ? widgetData.showProgressRing : widgetMetadata.showProgressRing
  property string valuePanelVisualizerPlacement: widgetData.panelVisualizerPlacement !== undefined ? widgetData.panelVisualizerPlacement : widgetMetadata.panelVisualizerPlacement
  property int valuePanelAlbumArtSize: widgetData.panelAlbumArtSize !== undefined ? widgetData.panelAlbumArtSize : widgetMetadata.panelAlbumArtSize
  // 0 means "fill the card", so the size slider is hidden while it is set and
  // the toggle below owns the behaviour instead.
  property bool valuePanelAlbumArtFill: valuePanelAlbumArtSize === 0
  property string valueTextColor: widgetData.textColor !== undefined ? widgetData.textColor : widgetMetadata.textColor

  Component.onCompleted: {
    if (widgetData && widgetData.hideMode !== undefined) {
      valueHideMode = widgetData.hideMode;
    }
  }

  function saveSettings() {
    var settings = Object.assign({}, widgetData || {});
    settings.hideMode = valueHideMode;
    // No longer store hideWhenIdle separately; kept for backward compatibility only
    settings.showAlbumArt = valueShowAlbumArt;
    settings.panelShowAlbumArt = valuePanelShowAlbumArt;
    settings.showArtistFirst = valueShowArtistFirst;
    settings.showTrackTitle = valueShowTrackTitle;
    settings.showArtist = valueShowArtist;
    settings.showVisualizer = valueShowVisualizer;
    settings.visualizerType = valueVisualizerType;
    settings.scrollingMode = valueScrollingMode;
    settings.maxWidth = parseInt(widthInput.text) || widgetMetadata.maxWidth;
    settings.useFixedWidth = valueUseFixedWidth;
    settings.showProgressRing = valueShowProgressRing;
    settings.panelVisualizerPlacement = valuePanelVisualizerPlacement;
    // Clamp on the way out: a hand-edited settings file can hold a value the
    // card would reject, and writing it straight back would keep it there.
    settings.panelAlbumArtSize = Math.max(0, Math.min(valuePanelAlbumArtSize, root.albumArtSizeBounds[1]));
    settings.textColor = valueTextColor;
    settingsChanged(settings);
  }

  NComboBox {
    Layout.fillWidth: true
    label: "Hiding mode"
    description: "Controls how the widget behaves when no media is playing."
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
      },
      {
        "key": "idle",
        "name": "Hide when idle"
      }
    ]
    currentKey: root.valueHideMode
    onSelected: key => {
                  root.valueHideMode = key;
                  saveSettings();
                }
    defaultValue: widgetMetadata.hideMode
  }

  NToggle {
    label: "Show album art"
    description: "Display the album artwork for the currently playing track."
    checked: valueShowAlbumArt
    onToggled: checked => {
                 valueShowAlbumArt = checked;
                 saveSettings();
               }
    defaultValue: widgetMetadata.showAlbumArt
  }

  NToggle {
    label: "Show artist first"
    description: "Display artist - title instead of title - artist."
    checked: valueShowArtistFirst
    onToggled: checked => {
                 valueShowArtistFirst = checked;
                 saveSettings();
               }
    defaultValue: widgetMetadata.showArtistFirst
  }

  NToggle {
    label: "Show track title"
    description: "Display the track title in the media player."
    checked: valueShowTrackTitle
    onToggled: checked => {
                 valueShowTrackTitle = checked;
                 saveSettings();
               }
    defaultValue: widgetMetadata.showTrackTitle
  }

  NToggle {
    label: "Show artist"
    description: "Display the artist in the media player."
    checked: valueShowArtist
    onToggled: checked => {
                 valueShowArtist = checked;
                 saveSettings();
               }
    defaultValue: widgetMetadata.showArtist
  }

  NToggle {
    label: "Show visualizer"
    description: "Display an audio visualizer when music is playing."
    checked: valueShowVisualizer
    onToggled: checked => {
                 valueShowVisualizer = checked;
                 saveSettings();
               }
    defaultValue: widgetMetadata.showVisualizer
  }

  NComboBox {
    visible: valueShowVisualizer
    label: "Visualizer type"
    description: "Choose the style of audio visualizer to display."
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
    minimumWidth: 200
    defaultValue: widgetMetadata.visualizerType
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
    label: "Use fixed width"
    description: "When enabled, the widget will always use the maximum width instead of dynamically adjusting to content."
    checked: valueUseFixedWidth
    onToggled: checked => {
                 valueUseFixedWidth = checked;
                 saveSettings();
               }
    defaultValue: widgetMetadata.useFixedWidth
  }

  NToggle {
    label: "Show progress ring"
    description: "Display a circular progress indicator showing track progress."
    checked: valueShowProgressRing
    onToggled: checked => {
                 valueShowProgressRing = checked;
                 saveSettings();
               }
    defaultValue: widgetMetadata.showProgressRing
  }

  NColorChoice {
    currentKey: valueTextColor
    onSelected: key => {
                  valueTextColor = key;
                  saveSettings();
                }
    defaultValue: widgetMetadata.textColor
  }

  NComboBox {
    label: "Scrolling mode"
    description: "Control when text scrolling is enabled for long track titles."
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
    onSelected: key => {
                  valueScrollingMode = key;
                  saveSettings();
                }
    minimumWidth: 200
    defaultValue: widgetMetadata.scrollingMode
  }

  NDivider {
    Layout.fillWidth: true
    Layout.topMargin: Style.marginS
  }

  NLabel {
    label: "Media player panel"
    description: "Configure the appearance and behavior of the media player panel."
    labelColor: Color.mPrimary
  }

  NToggle {
    label: "Show album art"
    description: "Display the album artwork for the currently playing track."
    checked: valuePanelShowAlbumArt
    onToggled: checked => {
                 valuePanelShowAlbumArt = checked;
                 saveSettings();
               }
    defaultValue: widgetMetadata.panelShowAlbumArt
  }

  NComboBox {
    visible: valueShowVisualizer
    label: "Panel visualizer placement"
    description: "Where to show the audio visualizer in the media player panel."
    model: [
      {
        "key": "art",
        "name": "Overlay on album art"
      },
      {
        "key": "background",
        "name": "Behind controls"
      },
      {
        "key": "none",
        "name": "No visualizer"
      }
    ]
    currentKey: valuePanelVisualizerPlacement
    onSelected: key => {
                  valuePanelVisualizerPlacement = key;
                  saveSettings();
                }
    minimumWidth: 200
    defaultValue: widgetMetadata.panelVisualizerPlacement
  }

  NToggle {
    visible: valuePanelShowAlbumArt
    label: "Fill available space"
    description: "Size the album artwork to whatever room is left in the media card after the controls."
    checked: valuePanelAlbumArtFill
    onToggled: checked => {
                 if (checked) {
                   // Entering fill mode stores the sentinel 0 in the settings.
                   valuePanelAlbumArtSize = 0;
                 } else if (valuePanelAlbumArtSize === 0) {
                   // Leaving fill mode needs a concrete size, so seed the slider
                   // from the default rather than from 0.
                   valuePanelAlbumArtSize = widgetMetadata.panelAlbumArtSize || root.albumArtSizeBounds[0];
                 }
                 saveSettings();
               }
    defaultValue: widgetMetadata.panelAlbumArtSize === 0
  }

  NValueSlider {
    visible: valuePanelShowAlbumArt && !valuePanelAlbumArtFill
    label: "Album art size"
    description: "Caps the album artwork at a fixed size. The card shrinks it further when its cell is too short to fit this."
    from: root.albumArtSizeBounds[0]
    to: root.albumArtSizeBounds[1]
    stepSize: 5
    value: valuePanelAlbumArtSize
    text: valuePanelAlbumArtSize + "px"
    onMoved: val => {
               valuePanelAlbumArtSize = val;
               saveSettings();
             }
    showReset: true
    defaultValue: widgetMetadata.panelAlbumArtSize || root.albumArtSizeBounds[0]
  }
}
