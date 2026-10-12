// File: Services/UI/DashboardPanelService.qml
// =============================================================================
// Entry point for "open the dashboard", optionally on a specific page.
//
// Every caller outside the panel itself (bar widgets, dashboard shortcut
// buttons, the settings panel, IPC) goes through here so the pending-page
// bookkeeping lives in one place. The dashboard does not remember the last page
// across opens, so callers should always pass the page they mean; omitting it
// falls back to DashboardPanel.Page.Home, which is always index 0.
//
// Functions:
//   openPage(page, screen, buttonItem)   - Open the dashboard on a page
//   togglePage(page, screen, buttonItem) - Open on a page, or close if already there
//   isOpen(screen)                      - Whether the dashboard is showing
//   currentPage(screen)                 - Page currently shown, -1 if unknown
//   resolve(screen)                     - Panel instance for a screen, or null
// =============================================================================

pragma Singleton

import QtQuick
// Required for Quickshell's scanner to register this file as a qs.* singleton.
// Without it the file is compiled as a plain component and `Singleton` fails
// to resolve with "Singleton is not a type".
import Quickshell
import qs.Commons
import qs.Modules.Panels.Dashboard
import qs.Services.UI

Singleton {
  id: root

  // Open the dashboard on a specific page. buttonItem is only used when
  // dashboard.position is "close_to_bar_button", matching the bar widget.
  function openPage(page, screen, buttonItem) {
    var panel = resolve(screen);
    if (!panel)
      return;
    panel.openPage(page !== undefined ? page : DashboardPanel.Page.Home, buttonItem);
  }

  // Toggle on a specific page: closes the panel when it is already showing
  // that page, which is what a settings button or bar widget should do.
  function togglePage(page, screen, buttonItem) {
    var panel = resolve(screen);
    if (!panel)
      return;
    panel.togglePage(page !== undefined ? page : DashboardPanel.Page.Home, buttonItem);
  }

  // Whether the dashboard is currently showing on this screen. Callers use it
  // to suppress tooltips while the panel is up.
  function isOpen(screen) {
    return resolve(screen)?.isPanelOpen === true;
  }

  // Page currently shown, or -1 when the panel cannot be resolved.
  function currentPage(screen) {
    var panel = resolve(screen);
    return panel ? panel.currentPage : -1;
  }

  // The dashboard instance for a screen. Mirrors PanelService.getPanel's
  // fallback so callers on a screen without the bar still land somewhere.
  function resolve(screen) {
    if (!screen) {
      Logger.w("DashboardPanelService", "Screen parameter required");
      return null;
    }
    return PanelService.getPanel("dashboardPanel", screen);
  }
}
