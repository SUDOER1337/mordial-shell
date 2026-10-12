import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Services.System
import qs.Services.UI
import qs.Widgets

ColumnLayout {
  id: root
  spacing: Style.marginL
  Layout.fillWidth: true
  Layout.fillHeight: true

  required property var availableWidgets

  signal addWidgetToSection(string widgetId, string section)
  signal removeWidgetFromSection(string section, int index)
  signal reorderWidgetInSection(string section, int fromIndex, int toIndex)
  signal updateWidgetSettingsInSection(string section, int index, var settings)
  signal moveWidgetBetweenSections(string fromSection, int index, string toSection)

  function getSectionIcons() {
    return {
      "left": "arrow-bar-to-up",
      "right": "arrow-bar-to-down"
    };
  }

  // Widgets Management Section
  ColumnLayout {
    spacing: Style.marginXXS
    Layout.fillWidth: true

    // Sections
    ColumnLayout {
      Layout.fillWidth: true
      Layout.fillHeight: true
      Layout.topMargin: Style.marginM
      spacing: Style.marginM

      // Left
      NSectionEditor {
        sectionName: "Left"
        sectionId: "left"
        settingsDialogComponent: Qt.resolvedUrl(Quickshell.shellDir + "/Modules/Panels/Settings/Dashboard/DashboardWidgetSettingsDialog.qml")
        maxWidgets: Settings.data.dashboard.shortcuts["left"].length > 5 ? 0 : (Settings.data.dashboard.shortcuts["left"].length > 0 ? 5 : 10)
        widgetRegistry: DashboardWidgetRegistry
        widgetModel: Settings.data.dashboard.shortcuts["left"]
        sectionIcons: root.getSectionIcons()
        availableWidgets: root.availableWidgets
        availableSections: ["left", "right"]
        onAddWidget: (widgetId, section) => root.addWidgetToSection(widgetId, section)
        onRemoveWidget: (section, index) => root.removeWidgetFromSection(section, index)
        onReorderWidget: (section, fromIndex, toIndex) => root.reorderWidgetInSection(section, fromIndex, toIndex)
        onUpdateWidgetSettings: (section, index, settings) => root.updateWidgetSettingsInSection(section, index, settings)
        onMoveWidget: (fromSection, index, toSection) => root.moveWidgetBetweenSections(fromSection, index, toSection)
      }

      // Right
      NSectionEditor {
        sectionName: "Right"
        sectionId: "right"
        settingsDialogComponent: Qt.resolvedUrl(Quickshell.shellDir + "/Modules/Panels/Settings/Dashboard/DashboardWidgetSettingsDialog.qml")
        maxWidgets: Settings.data.dashboard.shortcuts["right"].length > 5 ? 0 : (Settings.data.dashboard.shortcuts["right"].length > 0 ? 5 : 10)
        widgetRegistry: DashboardWidgetRegistry
        widgetModel: Settings.data.dashboard.shortcuts["right"]
        sectionIcons: root.getSectionIcons()
        availableWidgets: root.availableWidgets
        availableSections: ["left", "right"]
        onAddWidget: (widgetId, section) => root.addWidgetToSection(widgetId, section)
        onRemoveWidget: (section, index) => root.removeWidgetFromSection(section, index)
        onReorderWidget: (section, fromIndex, toIndex) => root.reorderWidgetInSection(section, fromIndex, toIndex)
        onUpdateWidgetSettings: (section, index, settings) => root.updateWidgetSettingsInSection(section, index, settings)
        onMoveWidget: (fromSection, index, toSection) => root.moveWidgetBetweenSections(fromSection, index, toSection)
      }
    }
  }

  Rectangle {
    Layout.fillHeight: true
  }
}
