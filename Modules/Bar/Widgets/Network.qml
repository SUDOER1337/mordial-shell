import QtQuick
import QtQuick.Controls
import Quickshell
import qs.Commons
import qs.Modules.Bar.Extras
import qs.Modules.Panels.Settings // For SettingsPanel
import qs.Services.Networking
import qs.Services.UI
import qs.Widgets

Item {
  id: root

  property ShellScreen screen

  // Widget properties passed from Bar.qml for per-instance settings
  property string widgetId: ""
  property string section: ""
  property int sectionWidgetIndex: -1
  property int sectionWidgetsCount: 0

  property var widgetMetadata: BarWidgetRegistry.widgetMetadata[widgetId] ?? {}
  // Explicit screenName property ensures reactive binding when screen changes
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

  readonly property string barPosition: Settings.getBarPositionForScreen(screenName)
  readonly property bool isBarVertical: barPosition === "left" || barPosition === "right"
  readonly property string displayMode: widgetSettings.displayMode !== undefined ? widgetSettings.displayMode : widgetMetadata.displayMode
  readonly property string iconColorKey: widgetSettings.iconColor !== undefined ? widgetSettings.iconColor : widgetMetadata.iconColor
  readonly property string textColorKey: widgetSettings.textColor !== undefined ? widgetSettings.textColor : widgetMetadata.textColor

  implicitWidth: pill.width
  implicitHeight: pill.height

  NPopupContextMenu {
    id: contextMenu

    model: [
      {
        "label": NetworkService.wifiEnabled ? "Disable Wi-Fi" : "Enable Wi-Fi",
        "action": "toggle-wifi",
        "icon": NetworkService.wifiEnabled ? "wifi-off" : "wifi",
        "enabled": !NetworkService.airplaneModeEnabled && NetworkService.wifiAvailable
      },
      {
        "label": "Wi-Fi" + " " + "Settings",
        "action": "wifi-settings",
        "icon": "settings"
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

                   if (action === "toggle-wifi") {
                     NetworkService.setWifiEnabled(!NetworkService.wifiEnabled);
                   } else if (action === "wifi-settings") {
                     SettingsPanelService.openToTab(SettingsPanel.Tab.Connections, 0, screen);
                   } else if (action === "widget-settings") {
                     BarService.openWidgetSettings(screen, section, sectionWidgetIndex, widgetId, widgetSettings);
                   }
                 }
  }

  BarPill {
    id: pill
    screen: root.screen
    oppositeDirection: BarService.getPillDirection(root)
    customIconColor: Color.resolveColorKeyOptional(root.iconColorKey)
    customTextColor: Color.resolveColorKeyOptional(root.textColorKey)
    icon: NetworkService.getIcon()
    text: NetworkService.getStatusText(false)
    autoHide: false
    forceOpen: !isBarVertical && root.displayMode === "alwaysShow"
    forceClose: isBarVertical || root.displayMode === "alwaysHide" || text === ""
    hoverOpensPanel: true
    onEntered: {
      HoverPanelService.arm({
                              "screen": screen,
                              "anchor": pill,
                              "panel": "networkPanel",
                              "open": () => PanelService.getPanel("networkPanel", screen)?.open(pill)
                            });
    }
    onExited: HoverPanelService.disarm(pill)
    onClicked: {
      var panel = PanelService.getPanel("networkPanel", screen);
      panel?.toggle(this);
    }
    onRightClicked: {
      PanelService.showContextMenu(contextMenu, pill, screen);
    }
    tooltipText: {
      if (PanelService.getPanel("networkPanel", screen)?.isPanelOpen) {
        return "";
      }
      return NetworkService.getStatusText(true);
    }
  }
}
