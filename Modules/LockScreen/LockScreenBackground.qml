// File: Modules/LockScreen/LockScreenBackground.qml
// =============================================================================
// Island lock background: a solid near-black ground. When music plays (and
// "Media on lock" is enabled) the track's cover is painted as a coarse wash —
// the artwork is pre-shrunk to a tenth of the screen and stretched back up
// through a heavy blur with lowered brightness and lifted saturation, then a
// flat black scrim keeps separation. No wallpaper here: the ground is the
// look.
//
// Functions:
//   (declarative component) - no imperative logic
// =============================================================================

import QtQuick
import QtQuick.Effects
import Quickshell
import qs.Commons
import qs.Services.Media

Item {
  id: root
  anchors.fill: parent

  required property var screen

  // --- Ground black ---
  Rectangle {
    anchors.fill: parent
    color: "#000000"
  }

  // --- Album-art wash ---
  Item {
    id: mediaWash

    readonly property string artUrl: MediaService.trackArtUrl || ""
    visible: Settings.data.islandLook.mediaOnLock && artUrl !== ""
    anchors.fill: parent

    Image {
      anchors.fill: parent
      fillMode: Image.PreserveAspectCrop
      source: mediaWash.artUrl
      cache: false
      smooth: true
      sourceSize {
        width: Math.max(1, Math.round(root.width * Look.washScale))
        height: Math.max(1, Math.round(root.height * Look.washScale))
      }

      layer.enabled: true
      layer.smooth: false
      layer.effect: MultiEffect {
        blurEnabled: true
        blur: Look.washBlur
        blurMax: Look.washBlurMax
        brightness: Look.washBrightness
        saturation: Look.washSaturation
      }
    }
  }

  // --- Flat black scrim for separation ---
  Rectangle {
    anchors.fill: parent
    color: Qt.rgba(0, 0, 0, Look.lockScrimOpacity)
  }

  // --- Screen corners for lock screen ---
  Item {
    anchors.fill: parent
    visible: Settings.data.general.showScreenCorners

    property color cornerColor: Settings.data.general.forceBlackScreenCorners ? "black" : Color.mSurface
    property real cornerRadius: Style.screenRadius
    property real cornerSize: Style.screenRadius

    // Top-left concave corner
    Canvas {
      anchors.top: parent.top
      anchors.left: parent.left
      width: parent.cornerSize
      height: parent.cornerSize
      antialiasing: true
      renderTarget: Canvas.FramebufferObject
      smooth: false

      onPaint: {
        const ctx = getContext("2d");
        if (!ctx)
          return;
        ctx.reset();
        ctx.clearRect(0, 0, width, height);

        ctx.fillStyle = parent.cornerColor;
        ctx.fillRect(0, 0, width, height);

        ctx.globalCompositeOperation = "destination-out";
        ctx.fillStyle = "#ffffff";
        ctx.beginPath();
        ctx.arc(width, height, parent.cornerRadius, 0, 2 * Math.PI);
        ctx.fill();
      }

      onWidthChanged: if (available)
                        requestPaint()
      onHeightChanged: if (available)
                         requestPaint()
    }

    // Top-right concave corner
    Canvas {
      anchors.top: parent.top
      anchors.right: parent.right
      width: parent.cornerSize
      height: parent.cornerSize
      antialiasing: true
      renderTarget: Canvas.FramebufferObject
      smooth: true

      onPaint: {
        const ctx = getContext("2d");
        if (!ctx)
          return;
        ctx.reset();
        ctx.clearRect(0, 0, width, height);

        ctx.fillStyle = parent.cornerColor;
        ctx.fillRect(0, 0, width, height);

        ctx.globalCompositeOperation = "destination-out";
        ctx.fillStyle = "#ffffff";
        ctx.beginPath();
        ctx.arc(0, height, parent.cornerRadius, 0, 2 * Math.PI);
        ctx.fill();
      }

      onWidthChanged: if (available)
                        requestPaint()
      onHeightChanged: if (available)
                         requestPaint()
    }

    // Bottom-left concave corner
    Canvas {
      anchors.bottom: parent.bottom
      anchors.left: parent.left
      width: parent.cornerSize
      height: parent.cornerSize
      antialiasing: true
      renderTarget: Canvas.FramebufferObject
      smooth: true

      onPaint: {
        const ctx = getContext("2d");
        if (!ctx)
          return;
        ctx.reset();
        ctx.clearRect(0, 0, width, height);

        ctx.fillStyle = parent.cornerColor;
        ctx.fillRect(0, 0, width, height);

        ctx.globalCompositeOperation = "destination-out";
        ctx.fillStyle = "#ffffff";
        ctx.beginPath();
        ctx.arc(width, 0, parent.cornerRadius, 0, 2 * Math.PI);
        ctx.fill();
      }

      onWidthChanged: if (available)
                        requestPaint()
      onHeightChanged: if (available)
                         requestPaint()
    }

    // Bottom-right concave corner
    Canvas {
      anchors.bottom: parent.bottom
      anchors.right: parent.right
      width: parent.cornerSize
      height: parent.cornerSize
      antialiasing: true
      renderTarget: Canvas.FramebufferObject
      smooth: false

      onPaint: {
        const ctx = getContext("2d");
        if (!ctx)
          return;
        ctx.reset();
        ctx.clearRect(0, 0, width, height);

        ctx.fillStyle = parent.cornerColor;
        ctx.fillRect(0, 0, width, height);

        ctx.globalCompositeOperation = "destination-out";
        ctx.fillStyle = "#ffffff";
        ctx.beginPath();
        ctx.arc(0, 0, parent.cornerRadius, 0, 2 * Math.PI);
        ctx.fill();
      }

      onWidthChanged: if (available)
                        requestPaint()
      onHeightChanged: if (available)
                         requestPaint()
    }
  }
}
