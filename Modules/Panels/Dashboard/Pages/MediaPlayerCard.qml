import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Services.Media
import qs.Services.UI
import qs.Widgets
import qs.Widgets.AudioSpectrum

// ============================================================
// MediaPlayerCard - Full-featured media player embedded as a card.
// Preserves the standalone MediaPlayerPanel look (album art, visualizer,
// scrollable metadata, seek slider, prev/play/next, player selector) while
// rendering as a fixed top card inside the combined Dashboard.
//
// The card uses a portrait layout: album art on top, then metadata, seek bar
// and transport controls stacked in a column that is centred on both axes. The
// dashboard grid stretches the card wider and taller than that column, so
// anything that fills the card instead of the column would drift off-axis -
// hence the spacers and per-element centring further down. All other visual
// settings (visualizer type, scrolling mode, album art toggle, album art
// size) come from the MediaMini bar widget's settings; the blurred album
// art backdrop and the album art frame come from Settings ▸ Dashboard ▸ Media.
// ============================================================
NBox {
  id: root

  // === Bar/widget settings (same source as the standalone player) ===
  property ShellScreen screen

  property var mediaMiniSettings: {
    const widget = BarService.lookupWidget("MediaMini", screen?.name);
    return widget ? widget.widgetSettings : null;
  }

  function refreshMediaMiniSettings() {
    const widget = BarService.lookupWidget("MediaMini", screen?.name);
    root.mediaMiniSettings = widget ? widget.widgetSettings : null;
  }

  Connections {
    target: BarService
    function onActiveWidgetsChanged() {
      root.refreshMediaMiniSettings();
    }
  }

  Connections {
    target: Settings
    function onSettingsSaved() {
      root.refreshMediaMiniSettings();
    }
  }

  readonly property string visualizerType: (mediaMiniSettings && mediaMiniSettings.visualizerType !== undefined) ? mediaMiniSettings.visualizerType : "linear"
  readonly property bool showArtistFirst: !!(mediaMiniSettings && mediaMiniSettings.showArtistFirst !== undefined ? mediaMiniSettings.showArtistFirst : true)
  readonly property bool showTrackTitle: !!(mediaMiniSettings && mediaMiniSettings.showTrackTitle !== undefined ? mediaMiniSettings.showTrackTitle : true)
  readonly property bool showArtist: !!(mediaMiniSettings && mediaMiniSettings.showArtist !== undefined ? mediaMiniSettings.showArtist : true)
  readonly property bool showAlbumArt: !!(mediaMiniSettings && mediaMiniSettings.panelShowAlbumArt !== undefined ? mediaMiniSettings.panelShowAlbumArt : true)
  readonly property bool showVisualizer: !!(mediaMiniSettings && mediaMiniSettings.showVisualizer !== undefined ? mediaMiniSettings.showVisualizer : true)
  readonly property string panelVisualizerPlacement: (mediaMiniSettings && mediaMiniSettings.panelVisualizerPlacement !== undefined) ? mediaMiniSettings.panelVisualizerPlacement : "art"
  // 0 = fill whatever the card has left; otherwise an absolute size in
  // unscaled px. The fallback reads the registry rather than repeating the
  // number, so the card and the settings page can never disagree on the default.
  readonly property int panelAlbumArtSize: (mediaMiniSettings && mediaMiniSettings.panelAlbumArtSize !== undefined) ? mediaMiniSettings.panelAlbumArtSize : (BarWidgetRegistry.widgetMetadata["MediaMini"].panelAlbumArtSize ?? 0)
  // Shared with MediaMiniSettings so the slider cannot offer a size this card
  // then rejects. The card additionally clamps to its own column width, which
  // is the tighter of the two in practice.
  readonly property real albumArtSizeMax: BarWidgetRegistry.widgetSettingBounds["MediaMini"].panelAlbumArtSize[1]
  readonly property string scrollingMode: (mediaMiniSettings && mediaMiniSettings.scrollingMode !== undefined) ? mediaMiniSettings.scrollingMode : "hover"

  // === Dashboard settings (Settings ▸ Dashboard ▸ Media) ===
  // Frame drawn around the album artwork. A width of 0 draws no frame, which
  // is why the settings page hides the colour picker at that value rather than
  // leaving a control with nothing to tint.
  readonly property real albumArtFrameWidth: Math.max(0, Settings.data.dashboard.mediaCard.frameWidth) * Style.uiScaleRatio
  readonly property color albumArtFrameColor: Settings.data.dashboard.mediaCard.frameColor

  // Embedded card: narrow full-height column, content column centered and
  // width-capped. The header pill and the album art are both capped to stay
  // inside this width, so a long MPRIS identity or an oversized art setting
  // cannot push the column wider than intended.
  readonly property real cardContentWidth: Math.round(320 * Style.uiScaleRatio)
  readonly property real contentImplicitWidth: Math.max(headerRow.implicitWidth, root.cardContentWidth) + Style.margin2S
  // Width the seek bar and the playback buttons aim for, as a share of the
  // content column. They used to span the column minus a fixed margin, which
  // read as flush to the edges next to a full-width album square; a ratio keeps
  // both blocks visibly narrower than the artwork at any UI scale. Raise it to
  // widen them, lower it to tighten; 1 spans the whole column.
  readonly property real controlWidthRatio: 0.78
  readonly property real controlSideMargin: Math.round(root.cardContentWidth * (1 - root.controlWidthRatio) / 2)

  readonly property bool isPanelOpen: {
    const p = PanelService.getPanel("dashboardPanel", root.screen);
    return p ? p.isPanelOpen : false;
  }

  readonly property bool needsSpectrum: root.isPanelOpen && root.showVisualizer && root.visualizerType !== "" && root.visualizerType !== "none"

  onNeedsSpectrumChanged: {
    if (root.needsSpectrum) {
      SpectrumService.registerComponent("ccv5-mediacard");
    } else {
      SpectrumService.unregisterComponent("ccv5-mediacard");
    }
  }

  Component.onCompleted: {
    if (root.needsSpectrum) {
      SpectrumService.registerComponent("ccv5-mediacard");
    }
  }

  Component.onDestruction: {
    SpectrumService.unregisterComponent("ccv5-mediacard");
  }

  implicitHeight: mainLayout.implicitHeight + Style.margin2S
  implicitWidth: contentImplicitWidth
  // Artwork is sized from the height the layout hands this card, so clip as a
  // guarantee that a short cell can never bleed into the neighbouring one.
  clip: true

  Item {
    anchors.fill: parent
    layer.enabled: true
    layer.smooth: true
    layer.effect: MultiEffect {
      maskEnabled: true
      maskThresholdMin: 0.95
      maskSpreadAtMin: 0.15
      maskSource: ShaderEffectSource {
        sourceItem: Rectangle {
          width: root.width
          height: root.height
          radius: root.radius
          color: "white"
        }
      }
    }

    Image {
      id: blurredCover
      readonly property int dim: Math.round(256 * Style.uiScaleRatio)
      // Treated as a single switch: a 0 strength is skipped by the card
      // entirely so the layer is not left running a no-op shader pass.
      readonly property bool blurActive: Settings.data.dashboard.mediaBlur.enabled && Settings.data.dashboard.mediaBlur.strength > 0
      anchors.fill: parent
      visible: blurActive && source.toString() !== ""
      source: MediaService.trackArtUrl
      sourceSize: Qt.size(dim, dim)
      fillMode: Image.PreserveAspectCrop
      layer.enabled: blurActive
      layer.smooth: true
      layer.effect: MultiEffect {
        autoPaddingEnabled: false
        blurEnabled: true
        blurMax: 60
        blur: Settings.data.dashboard.mediaBlur.strength
      }
    }

    Rectangle {
      anchors.fill: parent
      color: Color.mSurface
      opacity: 0.65
      radius: root.radius
    }

    Rectangle {
      anchors.fill: parent
      color: "transparent"
      radius: root.radius
      border.color: root.border.color
      border.width: root.border.width
    }
  }

  ColumnLayout {
    id: mainLayout
    anchors.fill: parent
    anchors.margins: Style.marginS
    spacing: Style.marginS

    // === Header: title + player selector ===
    // Deliberately not fillWidth: the dashboard grid stretches this card wider
    // than its content column, so a filling row would pin the icon and pill to
    // the far left while the artwork below stays centred. Sizing the row to its
    // implicit width and centring it keeps the header on the artwork's axis.
    RowLayout {
      id: headerRow
      Layout.alignment: Qt.AlignHCenter
      spacing: Style.marginM

      NIcon {
        icon: "music"
        pointSize: Style.fontSizeL
        color: Color.mPrimary
      }
      Rectangle {
        radius: Style.iRadiusS
        color: playerSelectorMouse.containsMouse ? Color.mPrimary : "transparent"
        implicitWidth: playerRow.implicitWidth + Style.marginM
        implicitHeight: Style.baseWidgetSize * 0.8
        visible: MediaService.getAvailablePlayers().length > 1

        RowLayout {
          id: playerRow
          anchors.centerIn: parent
          spacing: Style.marginXS

          NText {
            text: MediaService.currentPlayer ? MediaService.currentPlayer.identity : "Select Player"
            pointSize: Style.fontSizeXS
            color: playerSelectorMouse.containsMouse ? Color.mOnPrimary : Color.mOnSurfaceVariant
            // Capped so a long player identity cannot widen the card column;
            // NText already elides right and never wraps.
            Layout.preferredWidth: Math.round(96 * Style.uiScaleRatio)
            Layout.maximumWidth: Math.round(96 * Style.uiScaleRatio)
          }
          NIcon {
            icon: "chevron-down"
            pointSize: Style.fontSizeXS
            color: playerSelectorMouse.containsMouse ? Color.mOnPrimary : Color.mOnSurfaceVariant
          }
        }

        MouseArea {
          id: playerSelectorMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: playerContextMenu.open()
        }

        Popup {
          id: playerContextMenu
          x: 0
          y: parent.height
          width: 160
          padding: Style.marginS

          background: Rectangle {
            color: Color.mSurfaceVariant
            border.color: Color.mOutline
            border.width: Style.borderS
            radius: Style.iRadiusM
          }

          contentItem: ColumnLayout {
            spacing: 0
            Repeater {
              model: MediaService.getAvailablePlayers()
              delegate: Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 30
                color: "transparent"

                Rectangle {
                  anchors.fill: parent
                  color: itemMouse.containsMouse ? Color.mPrimary : "transparent"
                  radius: Style.iRadiusS
                }

                RowLayout {
                  anchors.fill: parent
                  anchors.margins: Style.marginS
                  spacing: Style.marginS

                  NIcon {
                    visible: MediaService.currentPlayer && MediaService.currentPlayer.identity === modelData.identity
                    icon: "check"
                    color: itemMouse.containsMouse ? Color.mOnPrimary : Color.mPrimary
                    pointSize: Style.fontSizeS
                  }

                  NText {
                    text: modelData.identity
                    pointSize: Style.fontSizeS
                    color: itemMouse.containsMouse ? Color.mOnPrimary : Color.mOnSurface
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                  }
                }

                MouseArea {
                  id: itemMouse
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: {
                    MediaService.currentPlayer = modelData;
                    playerContextMenu.close();
                  }
                }
              }
            }
          }
        }
      }
    }

    // === Player body: album art + controls ===
    Item {
      id: mediaBody
      Layout.fillWidth: true
      // Fills whatever height the surrounding layout gives the card, so the
      // artwork below can shrink to fit instead of overflowing its cell.
      Layout.fillHeight: true
      Layout.minimumHeight: Math.round(120 * Style.uiScaleRatio)

      // Visualizer background for content area
      Loader {
        anchors.fill: parent
        z: 0
        active: !!(root.needsSpectrum && root.panelVisualizerPlacement !== "none" && (!root.showAlbumArt || root.panelVisualizerPlacement !== "art"))
        sourceComponent: visualizerSource
      }

      ColumnLayout {
        id: mediaStack
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Style.marginM
        anchors.horizontalCenter: parent.horizontalCenter
        width: Math.min(parent.width, root.cardContentWidth)
        spacing: Style.marginM

        // A ColumnLayout packs its children against the top, so with a fixed
        // album art size (or artwork hidden) the block would hang high in a tall
        // card. These two stretchy spacers split the leftover height evenly, so
        // the whole stack sits on the card's vertical centre. They collapse to
        // zero when the artwork is in fill mode and already eats the slack.
        Item {
          Layout.fillHeight: true
        }

        // Gaps `spacing` inserts between this column's children: the two spacers
        // plus artwork, metadata, seek block and transport row are six children,
        // so five gaps. The artwork budget below reserves all of them - counting
        // only the visible ones would overflow the stack by a gap or two and the
        // card's clip would cut the transport row off. Over-reserving only ever
        // leaves a gap's worth of slack for the spacers to swallow.
        readonly property int spacingCount: 5

        // Album art
        Item {
          id: albumArtItem
          // Fill mode drops the setting's cap entirely and lets the height
          // budget below be the only limit. A size above the card's column
          // width is clamped too, otherwise the square would spill sideways
          // into the neighbouring cell.
          readonly property real requestedArtSize: root.panelAlbumArtSize === 0 ? Number.POSITIVE_INFINITY : Math.round(Math.min(root.panelAlbumArtSize, root.albumArtSizeMax) * Style.uiScaleRatio)
          // Artwork is square, so it takes whatever vertical room the controls
          // leave behind, capped at the configured size. Height comes from
          // mediaBody (a layout-driven size) while the controls' implicit height
          // depends only on width, so this cannot form a binding loop.
          readonly property real artSize: Math.round(Math.max(0, Math.min(requestedArtSize, root.cardContentWidth, mediaStack.height - mediaControls.implicitHeight - progressColumn.implicitHeight - playbackControls.implicitHeight - mediaStack.spacing * mediaStack.spacingCount)))

          Layout.preferredWidth: artSize
          Layout.preferredHeight: artSize
          Layout.minimumWidth: artSize
          Layout.maximumWidth: artSize
          Layout.minimumHeight: artSize
          Layout.maximumHeight: artSize
          Layout.alignment: Qt.AlignHCenter
          visible: root.showAlbumArt

          NImageRounded {
            anchors.fill: parent
            radius: Style.radiusM
            imagePath: MediaService.trackArtUrl
            imageFillMode: Image.PreserveAspectCrop
            fallbackIcon: "disc"
            fallbackIconSize: Style.fontSizeXXXL * 3
            // The frame is drawn inside the artwork's bounds, so it eats into
            // the image rather than growing the square past its layout size.
            borderWidth: root.albumArtFrameWidth
            borderColor: root.albumArtFrameColor
          }

          Loader {
            anchors.fill: parent
            anchors.margins: Style.marginS
            z: 2
            active: !!(root.needsSpectrum && root.showAlbumArt && root.panelVisualizerPlacement === "art")
            sourceComponent: visualizerSource
          }
        }

        ColumnLayout {
          id: mediaControls
          Layout.fillWidth: true
          spacing: 0

          NScrollText {
            id: trackTitle
            Layout.fillWidth: true
            // The two blocks swap roles when "artist first" is on, so visibility
            // follows the role (title/artist) rather than the slot.
            visible: root.showArtistFirst ? root.showArtist : root.showTrackTitle
            maxWidth: parent.width
            text: {
              if (root.showArtistFirst) {
                return MediaService.trackArtist || (MediaService.trackAlbum || "Unknown Artist");
              } else {
                return MediaService.trackTitle || "No Media";
              }
            }

            scrollMode: {
              if (root.scrollingMode === "always")
                return NScrollText.ScrollMode.Always;
              if (root.scrollingMode === "hover")
                return NScrollText.ScrollMode.Hover;
              return NScrollText.ScrollMode.Never;
            }
            fadeExtent: 0.01
            fadeCornerRadius: Style.radiusM

            delegate: NText {
              pointSize: Style.fontSizeL
              font.weight: Style.fontWeightBold
              color: Color.mOnSurface
              horizontalAlignment: Text.AlignHCenter
              // Centre the text by matching the scroller's width; the loaded item
              // is otherwise content-sized, which makes horizontalAlignment a
              // no-op. Once the text outgrows that width, fall back to content
              // width so the marquee still scrolls instead of clipping evenly at
              // both edges.
              //
              // Compare against this NText's own implicitWidth, NOT
              // trackTitle.contentWidth: contentWidth falls back to the delegate's
              // width when implicitWidth is 0, so testing against it closes a loop
              // (contentWidth -> item.width -> this width -> contentWidth) and Qt
              // reports "Binding loop detected". implicitWidth is purely
              // content-derived and is what contentWidth returns when non-zero, so
              // behaviour is unchanged.
              width: implicitWidth <= trackTitle.maxWidth ? trackTitle.width : implicitWidth
              elide: Text.ElideNone
              wrapMode: Text.NoWrap
            }
          }

          NScrollText {
            id: trackSubtitle
            Layout.fillWidth: true
            visible: root.showArtistFirst ? root.showTrackTitle : root.showArtist
            maxWidth: parent.width
            text: {
              if (root.showArtistFirst) {
                return MediaService.trackTitle || "No Media";
              } else {
                return MediaService.trackArtist || (MediaService.trackAlbum || "Unknown Artist");
              }
            }

            scrollMode: {
              if (root.scrollingMode === "always")
                return NScrollText.ScrollMode.Always;
              if (root.scrollingMode === "hover")
                return NScrollText.ScrollMode.Hover;
              return NScrollText.ScrollMode.Never;
            }
            fadeExtent: 0.01
            fadeCornerRadius: Style.radiusM

            delegate: NText {
              pointSize: Style.fontSizeS
              color: Color.mOnSurfaceVariant
              // Same treatment as the title line above: match the scroller's
              // width so the text centres on the card, and only fall back to the
              // content width once the text outgrows it so the marquee scrolls
              // instead of clipping evenly at both edges. Tested against this
              // item's own implicitWidth, never trackSubtitle.contentWidth,
              // which would close a binding loop.
              width: implicitWidth <= trackSubtitle.maxWidth ? trackSubtitle.width : implicitWidth
              horizontalAlignment: Text.AlignHCenter
              elide: Text.ElideNone
              wrapMode: Text.NoWrap
            }
          }
        }

        Item {
          id: progressWrapper
          visible: (MediaService.currentPlayer && MediaService.trackLength > 0)
          Layout.fillWidth: true
          Layout.preferredHeight: progressColumn.implicitHeight
          Layout.leftMargin: root.controlSideMargin
          Layout.rightMargin: root.controlSideMargin

          property real localSeekRatio: -1
          property real lastSentSeekRatio: -1
          property real seekEpsilon: 0.01
          property real progressRatio: {
            if (!MediaService.currentPlayer || MediaService.trackLength <= 0)
              return 0;
            const r = MediaService.currentPosition / MediaService.trackLength;
            if (isNaN(r) || !isFinite(r))
              return 0;
            return Math.max(0, Math.min(1, r));
          }

          Timer {
            id: seekDebounce
            interval: 75
            repeat: false
            onTriggered: {
              if (MediaService.isSeeking && progressWrapper.localSeekRatio >= 0) {
                const next = Math.max(0, Math.min(1, progressWrapper.localSeekRatio));
                if (progressWrapper.lastSentSeekRatio < 0 || Math.abs(next - progressWrapper.lastSentSeekRatio) >= progressWrapper.seekEpsilon) {
                  MediaService.seekByRatio(next);
                  progressWrapper.lastSentSeekRatio = next;
                }
              }
            }
          }

          ColumnLayout {
            id: progressColumn
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            spacing: 2

            Item {
              Layout.fillWidth: true
              Layout.preferredHeight: Style.baseWidgetSize * 0.4

              NSlider {
                id: progressSlider
                anchors.fill: parent
                from: 0
                to: 1
                stepSize: 0
                snapAlways: false
                enabled: MediaService.trackLength > 0 && MediaService.canSeek
                heightRatio: 0.4

                value: (!MediaService.isSeeking) ? progressWrapper.progressRatio : (progressWrapper.localSeekRatio >= 0 ? progressWrapper.localSeekRatio : 0)

                onMoved: {
                  progressWrapper.localSeekRatio = value;
                  seekDebounce.restart();
                }
                onPressedChanged: {
                  if (pressed) {
                    MediaService.isSeeking = true;
                    progressWrapper.localSeekRatio = value;
                    MediaService.seekByRatio(value);
                    progressWrapper.lastSentSeekRatio = value;
                  } else {
                    seekDebounce.stop();
                    MediaService.seekByRatio(value);
                    MediaService.isSeeking = false;
                    progressWrapper.localSeekRatio = -1;
                    progressWrapper.lastSentSeekRatio = -1;
                  }
                }
              }
            }

            RowLayout {
              Layout.fillWidth: true
              spacing: 0

              NText {
                text: MediaService.positionString || "0:00"
                pointSize: Style.fontSizeXS
                color: Color.mOnSurfaceVariant
                visible: progressWrapper.visible
              }

              Item {
                Layout.fillWidth: true
                Layout.minimumWidth: 0
              }

              NText {
                text: MediaService.lengthString || "0:00"
                pointSize: Style.fontSizeXS
                color: Color.mOnSurfaceVariant
                horizontalAlignment: Text.AlignRight
                visible: progressWrapper.visible
              }
            }
          }
        }

        RowLayout {
          id: playbackControls
          spacing: Style.marginL
          Layout.alignment: Qt.AlignHCenter
          Layout.leftMargin: root.controlSideMargin
          Layout.rightMargin: root.controlSideMargin

          NIconButton {
            icon: "media-prev"
            baseSize: Style.baseWidgetSize * 0.9
            onClicked: MediaService.previous()
          }

          Rectangle {
            implicitWidth: Style.baseWidgetSize * 1.3
            implicitHeight: Style.baseWidgetSize * 1.3
            radius: Style.iRadiusM
            color: Color.mPrimary

            NIcon {
              anchors.centerIn: parent
              icon: MediaService.isPlaying ? "media-pause" : "media-play"
              pointSize: Style.fontSizeL
              color: Color.mOnPrimary
            }

            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              hoverEnabled: true
              onClicked: MediaService.playPause()
            }
          }

          NIconButton {
            icon: "media-next"
            baseSize: Style.baseWidgetSize * 0.9
            onClicked: MediaService.next()
          }
        }

        Item {
          Layout.fillHeight: true
        }
      }
    }
  }

  // Visualizer Components
  readonly property Component visualizerSource: {
    switch (root.visualizerType) {
    case "linear":
      return linearComponent;
    case "mirrored":
      return mirroredComponent;
    case "wave":
      return waveComponent;
    default:
      return null;
    }
  }

  Component {
    id: linearComponent
    NLinearSpectrum {
      anchors.fill: parent
      values: SpectrumService.values
      fillColor: Color.mPrimary
      opacity: 0.4
      barPosition: Settings.getBarPositionForScreen(root.screen?.name)
      mirrored: Settings.data.audio.spectrumMirrored
    }
  }

  Component {
    id: mirroredComponent
    NMirroredSpectrum {
      anchors.fill: parent
      values: SpectrumService.values
      fillColor: Color.mPrimary
      opacity: 0.9
      mirrored: Settings.data.audio.spectrumMirrored
    }
  }

  Component {
    id: waveComponent
    NWaveSpectrum {
      anchors.fill: parent
      values: SpectrumService.values
      fillColor: Color.mPrimary
      opacity: 0.4
      mirrored: Settings.data.audio.spectrumMirrored
    }
  }
}
