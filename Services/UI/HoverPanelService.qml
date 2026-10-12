// File: Services/UI/HoverPanelService.qml
// =============================================================================
// Central manager for "open panel on hover" bar widgets.
//
// A bar widget arms the service on hover-enter, passing the panel it wants to
// open plus a callback that performs the actual open. The service delays the
// open so that merely sweeping the cursor across the bar does not flash every
// panel in turn.
//
// Once a panel is open *because of hover*, the service keeps it open while the
// pointer is over either the widget or the panel, and closes it (after a short
// grace period, so the widget -> panel hand-off has time to land) when the
// pointer leaves both. Panels opened by a click are never touched: only the
// hover path arms the close tracking.
//
// Bar widgets and panels live in different windows, so hover state cannot be
// derived from a single MouseArea. Widgets report their own enter/exit, and
// SmartPanel reports the panel side through setPanelHovered().
//
// Functions:
//   arm(options)      - Widget hovered: cancel any pending close, schedule the open
//   disarm(anchor)    - Widget unhovered: schedule the close if we opened the panel
//   setPanelHovered() - Panel hovered: keep the panel open (see SmartPanel)
//   cancel()          - Drop all tracking (used when the panel closes by other means)
//
// Options accepted by arm():
//   screen      - ShellScreen the widget lives on (required)
//   anchor      - Widget item, used to ignore stale enter/exit pairs
//   panel       - PanelService name of the target panel, "" when there is none
//   open        - Callback performing the open (required)
//   trackPointer- false for panels that are not hover-aware (overlay launcher)
// =============================================================================

pragma Singleton

import QtQuick
// Required for Quickshell's scanner to register this file as a qs.* singleton.
// Without it the file is compiled as a plain component and `Singleton` fails
// to resolve with "Singleton is not a type".
import Quickshell
import qs.Commons
import qs.Services.UI

Singleton {
  id: root

  // Whether hover-to-open is active at all (mirrors bar.hoverOpenPanels)
  readonly property bool enabled: Settings.data.bar.hoverOpenPanels === true

  // The widget that is currently hovered, if any
  property var hoveredAnchor: null

  // Pending open for the hovered widget, or null when nothing is armed
  property var pending: null

  // True only between opening a panel on hover and losing the pointer entirely
  property bool trackingPanel: false

  // Pointer is over the widget that opened the current panel
  property bool widgetHovered: false

  // Pointer is over the panel that we opened (reported by SmartPanel)
  property bool panelHovered: false

  // Arm hover-to-open for a bar widget.
  // options: { screen, anchor, panel, open, trackPointer }
  function arm(options) {
    if (!enabled || !options || !options.anchor)
      return;

    hoveredAnchor = options.anchor;
    widgetHovered = true;

    // Moving onto a new widget cancels a close that is already in flight, so
    // sweeping along the bar switches panels instead of closing them.
    closeTimer.stop();

    if (options.trackPointer === false) {
      // Panel is not hover-aware (overlay launcher): open it, but never close
      // it on pointer-out. Still honour the open delay to avoid accidental opens.
      pending = {
        "track": false,
        "open": options.open
      };
    } else {
      pending = {
        "track": true,
        "panel": options.panel || "",
        "screen": options.screen,
        "open": options.open
      };
    }

    openTimer.restart();
  }

  // Handle a bar widget losing the hover.
  function disarm(anchor) {
    if (anchor && hoveredAnchor && anchor !== hoveredAnchor)
      return;

    hoveredAnchor = null;
    widgetHovered = false;
    openTimer.stop();

    if (trackingPanel)
      closeTimer.restart();
  }

  // Report whether the pointer is over a hover-opened panel.
  function setPanelHovered(hovered) {
    if (panelHovered === hovered)
      return;

    panelHovered = hovered;

    if (hovered) {
      // Pointer reached the panel: cancel a pending close, otherwise the
      // widget -> panel hand-off would close it right under the cursor.
      closeTimer.stop();
    } else if (trackingPanel) {
      closeTimer.restart();
    }
  }

  // Drop all hover tracking, e.g. once the panel closed by other means.
  function cancel() {
    openTimer.stop();
    closeTimer.stop();
    pending = null;
    trackingPanel = false;
    widgetHovered = false;
    panelHovered = false;
  }

  // Any other close path (Escape, click outside, another panel opening) drops
  // our tracking, so a later hover-out cannot close a panel the user opened.
  Connections {
    target: PanelService

    function onDidClose() {
      // A panel is still open: this close is the hand-off to the panel we just
      // opened on hover, and its close animation finishes after we armed.
      if (PanelService.openedPanel)
        return;

      if (root.trackingPanel)
        root.cancel();
    }
  }

  Timer {
    id: openTimer
    interval: Settings.data.bar.hoverOpenDelay
    repeat: false
    onTriggered: {
      var job = root.pending;
      root.pending = null;
      if (!job || !root.enabled)
      return;

      if (job.track) {
        // Opening an already-open panel would re-run its position logic, and
        // closing it on hover-out would fight the user who opened it by click.
        var panel = job.panel ? PanelService.getPanel(job.panel, job.screen) : null;
        if (panel && panel.isPanelOpen)
        return;

        job.open();
        root.trackingPanel = true;
      } else {
        job.open();
      }
    }
  }

  Timer {
    id: closeTimer
    interval: Settings.data.bar.hoverCloseDelay
    repeat: false
    onTriggered: {
      // Bail out if the feature was switched off while a panel was hover-open
      if (!root.enabled || !root.trackingPanel || root.widgetHovered || root.panelHovered)
      return;

      root.trackingPanel = false;
      PanelService.closePanel();
    }
  }
}
