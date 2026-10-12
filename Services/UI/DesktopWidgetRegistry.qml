pragma Singleton

import QtQuick
import Quickshell
import qs.Commons
import qs.Modules.DesktopWidgets.Widgets

Singleton {
  id: root

  // Transient state - not persisted, resets on shell restart
  property bool editMode: false

  // Component definitions
  property Component clockComponent: Component {
    DesktopClock {}
  }
  property Component mediaPlayerComponent: Component {
    DesktopMediaPlayer {}
  }
  property Component weatherComponent: Component {
    DesktopWeather {}
  }
  property Component systemStatComponent: Component {
    DesktopSystemStat {}
  }
  property Component audioVisualizerComponent: Component {
    DesktopAudioVisualizer {}
  }

  // Widget registry object mapping widget names to components
  // Created in Component.onCompleted to ensure Components are ready
  property var widgets: ({})

  // Explicit URLs for core widgets. Inline Component.url returns the parent
  // file's URL, so we need these for Loader.setSource() with initial properties.
  // Plugin widgets use their Component.url directly (loaded from actual files).
  readonly property string _widgetsDir: Quickshell.shellDir + "/Modules/DesktopWidgets/Widgets/"
  property var widgetUrls: ({})

  Component.onCompleted: {
    // Initialize widgets object after Components are ready
    var widgetsObj = {};
    widgetsObj["Clock"] = clockComponent;
    widgetsObj["MediaPlayer"] = mediaPlayerComponent;
    widgetsObj["Weather"] = weatherComponent;
    widgetsObj["SystemStat"] = systemStatComponent;
    widgetsObj["AudioVisualizer"] = audioVisualizerComponent;
    widgets = widgetsObj;

    var urlsObj = {};
    urlsObj["Clock"] = _widgetsDir + "DesktopClock.qml";
    urlsObj["MediaPlayer"] = _widgetsDir + "DesktopMediaPlayer.qml";
    urlsObj["Weather"] = _widgetsDir + "DesktopWeather.qml";
    urlsObj["SystemStat"] = _widgetsDir + "DesktopSystemStat.qml";
    urlsObj["AudioVisualizer"] = _widgetsDir + "DesktopAudioVisualizer.qml";
    widgetUrls = urlsObj;

    Logger.i("DesktopWidgetRegistry", "Service started");
  }

  property var widgetSettingsMap: ({
                                     "Clock": "WidgetSettings/ClockSettings.qml",
                                     "MediaPlayer": "WidgetSettings/MediaPlayerSettings.qml",
                                     "Weather": "WidgetSettings/WeatherSettings.qml",
                                     "SystemStat": "WidgetSettings/SystemStatSettings.qml",
                                     "AudioVisualizer": "WidgetSettings/AudioVisualizerSettings.qml"
                                   })

  property var widgetMetadata: ({
                                  "Clock": {
                                    "showBackground": true,
                                    "roundedCorners": true,
                                    "clockStyle": "digital",
                                    "clockColor": "none",
                                    "useCustomFont": false,
                                    "customFont": "",
                                    "format": "HH:mm\\nd MMMM yyyy"
                                  },
                                  "MediaPlayer": {
                                    "showBackground": true,
                                    "roundedCorners": true,
                                    "visualizerType": "linear",
                                    "hideMode": "visible",
                                    "showButtons": true,
                                    "showAlbumArt": true,
                                    "showVisualizer": true
                                  },
                                  "Weather": {
                                    "showBackground": true,
                                    "roundedCorners": true
                                  },
                                  "SystemStat": {
                                    "showBackground": true,
                                    "roundedCorners": true,
                                    "statType": "CPU",
                                    "diskPath": "/",
                                    "layout": "bottom"
                                  },
                                  "AudioVisualizer": {
                                    "showBackground": true,
                                    "roundedCorners": true,
                                    "width": 320,
                                    "height": 72,
                                    "visualizerType": "linear",
                                    "hideWhenIdle": false,
                                    "colorName": "primary"
                                  }
                                })

  property var cpuIntensiveWidgets: ["SystemStat", "AudioVisualizer"]

  function init() {
    Logger.i("DesktopWidgetRegistry", "Service started");
  }

  // Helper function to get widget component by name
  function getWidget(id) {
    return widgets[id] || null;
  }

  // Helper function to check if widget exists
  function hasWidget(id) {
    return id in widgets;
  }

  // Get list of available widget ids
  function getAvailableWidgets() {
    var keys = Object.keys(widgets);
    Logger.d("DesktopWidgetRegistry", "getAvailableWidgets() called, returning:", keys);
    return keys;
  }

  // Helper function to check if widget has user settings
  function widgetHasUserSettings(id) {
    return widgetMetadata[id] !== undefined;
  }

  function isCpuIntensive(id) {
    return cpuIntensiveWidgets.indexOf(id) >= 0;
  }

  // Get display name for a widget ID
  function getWidgetDisplayName(widgetId) {
    return widgetId;
  }

  function updateWidgetData(monitorName, widgetIndex, properties) {
    if (widgetIndex < 0 || !monitorName) {
      return;
    }

    var monitorWidgets = Settings.data.desktopWidgets.monitorWidgets || [];
    var newMonitorWidgets = monitorWidgets.slice();

    for (var i = 0; i < newMonitorWidgets.length; i++) {
      if (newMonitorWidgets[i].name === monitorName) {
        var widgets = (newMonitorWidgets[i].widgets || []).slice();
        if (widgetIndex < widgets.length) {
          widgets[widgetIndex] = Object.assign({}, widgets[widgetIndex], properties);
          newMonitorWidgets[i] = Object.assign({}, newMonitorWidgets[i], {
                                                 "widgets": widgets
                                               });
          Settings.data.desktopWidgets.monitorWidgets = newMonitorWidgets;
        }
        break;
      }
    }
  }

  property var currentSettingsDialog: null

  function openWidgetSettings(screen, widgetIndex, widgetId, widgetData) {
    if (!widgetId || !screen) {
      return;
    }

    if (root.currentSettingsDialog) {
      root.currentSettingsDialog.close();
      root.currentSettingsDialog.destroy();
      root.currentSettingsDialog = null;
    }

    var hasSettings = root.widgetSettingsMap[widgetId] !== undefined;

    if (!hasSettings) {
      Logger.w("DesktopWidgetRegistry", "Widget does not have settings:", widgetId);
      return;
    }

    var popupMenuWindow = PanelService.getPopupMenuWindow(screen);
    if (!popupMenuWindow) {
      Logger.e("DesktopWidgetRegistry", "No popup menu window found for screen");
      return;
    }

    if (popupMenuWindow.hideDynamicMenu) {
      popupMenuWindow.hideDynamicMenu();
    }

    var component = Qt.createComponent(Quickshell.shellDir + "/Modules/Panels/Settings/DesktopWidgets/DesktopWidgetSettingsDialog.qml");

    function instantiateAndOpen() {
      var dialog = component.createObject(popupMenuWindow.dialogParent, {
                                            "widgetIndex": widgetIndex,
                                            "widgetData": widgetData,
                                            "widgetId": widgetId,
                                            "sectionId": screen.name,
                                            "screen": screen
                                          });

      if (dialog) {
        root.currentSettingsDialog = dialog;
        dialog.updateWidgetSettings.connect((sec, idx, settings) => {
                                              root.updateWidgetData(sec, idx, settings);
                                            });
        popupMenuWindow.hasDialog = true;
        dialog.closed.connect(() => {
                                popupMenuWindow.hasDialog = false;
                                popupMenuWindow.close();
                                if (root.currentSettingsDialog === dialog) {
                                  root.currentSettingsDialog = null;
                                }
                                dialog.destroy();
                              });
        dialog.open();
      } else {
        Logger.e("DesktopWidgetRegistry", "Failed to create widget settings dialog");
      }
    }

    if (component.status === Component.Ready) {
      instantiateAndOpen();
    } else if (component.status === Component.Error) {
      Logger.e("DesktopWidgetRegistry", "Error loading settings dialog component:", component.errorString());
    } else {
      component.statusChanged.connect(() => {
                                        if (component.status === Component.Ready) {
                                          instantiateAndOpen();
                                        } else if (component.status === Component.Error) {
                                          Logger.e("DesktopWidgetRegistry", "Error loading settings dialog component:", component.errorString());
                                        }
                                      });
    }
  }
}
