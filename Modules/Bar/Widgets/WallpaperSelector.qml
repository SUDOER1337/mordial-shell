// File: Modules/Bar/Widgets/WallpaperSelector.qml
// =============================================================================
// Bar widget that opens the Dashboard on its wallpaper page (the wallpaper
// picker is a Dashboard page, not a panel of its own).
// =============================================================================

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Modules.Bar.Extras
import qs.Modules.Panels.Dashboard
import qs.Services.UI
import qs.Widgets

NIconButton {
  id: root

  property ShellScreen screen

  // Widget properties passed from Bar.qml for per-instance settings
  property string widgetId: ""
  property string section: ""
  property int sectionWidgetIndex: -1
  property int sectionWidgetsCount: 0

  property var widgetMetadata: BarWidgetRegistry.widgetMetadata[widgetId] ?? {}
  readonly property string screenName: screen ? screen.name : ""
  property var widgetSettings: {
    if (section && sectionWidgetIndex >= 0 && screenName) {
      var widgets = Settings.getBarWidgetsForScreen(screenName)[section];
      if (widgets && sectionWidgetIndex < widgets.length) {
        return widgets[sectionWidgetIndex];
      }
    }
    return {};
  }

  readonly property string iconColorKey: widgetSettings.iconColor !== undefined ? widgetSettings.iconColor : widgetMetadata.iconColor

  enabled: Settings.data.wallpaper.enabled
  baseSize: Style.getCapsuleHeightForScreen(screen?.name)
  applyUiScale: false
  customRadius: Style.radiusL
  icon: "wallpaper-selector"
  tooltipText: {
    if (DashboardPanelService.isOpen(screen)) {
      return "";
    } else {
      return "Wallpaper selector";
    }
  }
  tooltipDirection: BarService.getTooltipDirection(screen?.name)
  colorBg: Style.capsuleColor
  colorFg: Color.resolveColorKey(iconColorKey)
  border.color: Style.capsuleBorderColor
  border.width: Style.capsuleBorderWidth

  NPopupContextMenu {
    id: contextMenu

    model: [
      {
        "label": "Random wallpaper",
        "action": "random-wallpaper",
        "icon": "dice"
      },
      {
        "label": "Widget settings",
        "action": "widget-settings",
        "icon": "settings"
      },
    ]

    onTriggered: action => {
                   contextMenu.close();
                   PanelService.closeContextMenu(screen);

                   if (action === "random-wallpaper") {
                     WallpaperService.setRandomWallpaper();
                   } else if (action === "widget-settings") {
                     BarService.openWidgetSettings(screen, section, sectionWidgetIndex, widgetId, widgetSettings);
                   }
                 }
  }

  hoverOpensPanel: true
  onEntered: {
    HoverPanelService.arm({
                            "screen": screen,
                            "anchor": root,
                            "panel": "dashboardPanel",
                            "open": () => {
                              // Only opens when the dashboard is closed, so this
                              // never steals the page the user is looking at.
                              DashboardPanelService.openPage(DashboardPanel.Page.Wallpaper, screen, root);
                            }
                          });
  }
  onExited: HoverPanelService.disarm(root)

  onClicked: {
    DashboardPanelService.togglePage(DashboardPanel.Page.Wallpaper, screen, root);
  }
  onRightClicked: {
    PanelService.showContextMenu(contextMenu, root, screen);
  }
}
