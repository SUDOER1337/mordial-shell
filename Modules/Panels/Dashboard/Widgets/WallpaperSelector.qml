import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Modules.Panels.Dashboard
import qs.Services.UI
import qs.Widgets

NIconButtonHot {
  property ShellScreen screen

  enabled: Settings.data.wallpaper.enabled
  icon: "wallpaper-selector"
  tooltipText: "Wallpaper Selector"
  // The picker is a page of this very panel, so the button switches the
  // dashboard to it (or closes it, when it is already showing).
  onClicked: DashboardPanelService.togglePage(DashboardPanel.Page.Wallpaper, screen)
  onRightClicked: WallpaperService.setRandomWallpaper()
}
