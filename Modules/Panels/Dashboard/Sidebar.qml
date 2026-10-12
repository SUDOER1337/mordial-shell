import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Services.UI
import qs.Widgets

Item {
  id: root

  // Mirrors the Settings sidebar's look (Modules/Panels/Settings/SettingsContent.qml).
  // Unlike Settings this rail is permanently collapsed: the dashboard panel hugs
  // its content, so a hover-driven width change would resize the window and
  // reflow the page on every hover. Labels stay available via tooltips.
  property bool expanded: false
  // Driven by DashboardPanel.currentPage. The rail only emits tabSelected, so
  // there is exactly one source of truth for which page is active.
  property int currentIndex: 0

  signal tabSelected(int index)

  // One entry per DashboardPanel.Page, in the same order as the enum so
  // currentIndex doubles as the page id. Home stays at index 0.
  readonly property var tabs: [
    {
      icon: "home",
      label: "common.home"
    },
    {
      icon: "sparkles",
      label: "dashboard.aiChat"
    },
    {
      icon: "settings-wallpaper-selector",
      label: "common.wallpaper"
    },
  ]
  readonly property int tabCount: tabs.length

  readonly property real sidebarWidth: Math.round(52 * Style.uiScaleRatio)
  // Shared with the Settings sidebar so both rails flip together.
  readonly property bool cardStyle: Settings.data.ui.settingsPanelSideBarCardStyle

  implicitWidth: sidebarWidth
  implicitHeight: parent ? parent.height : 0

  NBox {
    anchors.fill: parent
    color: root.cardStyle ? Color.mSurfaceVariant : "transparent"
    radius: root.cardStyle ? Style.radiusM : 0
    border.color: root.cardStyle ? Style.boxBorderColor : "transparent"
    clip: true

    ColumnLayout {
      anchors.fill: parent
      anchors.margins: root.cardStyle ? Style.marginM : 0
      spacing: Style.marginXS

      // Nav items
      Item {
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.bottomMargin: Style.marginXL

        NListView {
          id: navList
          anchors.fill: parent
          model: root.tabs

          spacing: Style.marginXS
          // Declarative one-way binding. Do not also assign navList.currentIndex
          // imperatively: that would break this binding and the rail and the
          // page stack would disagree about which page is active.
          currentIndex: root.currentIndex
          horizontalPolicy: ScrollBar.AlwaysOff
          verticalPolicy: ScrollBar.AsNeeded
          gradientColor: "transparent"
          reserveScrollbarSpace: false

          delegate: Rectangle {
            id: tabItem
            width: navList.width
            height: tabEntryRow.implicitHeight + Style.margin2XS
            radius: Style.iRadiusS
            color: selected ? Color.mPrimary : (tabItem.hovering ? Color.mHover : "transparent")
            readonly property bool selected: index === root.currentIndex
            property bool hovering: false
            property color tabTextColor: selected ? Color.mOnPrimary : (tabItem.hovering ? Color.mOnHover : Color.mOnSurface)

            Behavior on color {
              enabled: !Color.isTransitioning
              ColorAnimation {
                duration: Style.animationFast
                easing.type: Easing.InOutQuad
              }
            }

            Behavior on tabTextColor {
              enabled: !Color.isTransitioning
              ColorAnimation {
                duration: Style.animationFast
                easing.type: Easing.InOutQuad
              }
            }

            RowLayout {
              id: tabEntryRow
              anchors.fill: parent
              anchors.leftMargin: Style.marginS
              anchors.rightMargin: Style.marginS
              spacing: Style.marginM

              NIcon {
                icon: modelData.icon
                color: tabItem.tabTextColor
                pointSize: Style.fontSizeXL
                Layout.alignment: Qt.AlignVCenter
              }

              NText {
                text: I18n.tr(modelData.label)
                color: tabItem.tabTextColor
                pointSize: Style.fontSizeM
                font.weight: Style.fontWeightSemiBold
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                visible: root.expanded
                opacity: root.expanded ? 1.0 : 0.0

                Behavior on opacity {
                  NumberAnimation {
                    duration: Style.animationFast
                    easing.type: Easing.InOutQuad
                  }
                }
              }
            }

            MouseArea {
              anchors.fill: parent
              hoverEnabled: true
              acceptedButtons: Qt.LeftButton
              cursorShape: Qt.PointingHandCursor
              onEntered: {
                tabItem.hovering = true;
                if (!root.expanded) {
                  TooltipService.show(tabItem, I18n.tr(modelData.label));
                }
              }
              onExited: {
                tabItem.hovering = false;
                if (!root.expanded) {
                  TooltipService.hide();
                }
              }
              onCanceled: {
                tabItem.hovering = false;
                if (!root.expanded) {
                  TooltipService.hide();
                }
              }
              onClicked: {
                // Only emit: currentIndex is owned by DashboardPanel.currentPage,
                // so writing it here too would fight that binding.
                root.tabSelected(index);
                if (!root.expanded) {
                  TooltipService.hide();
                }
              }
            }
          }
        }
      }
    }
  }
}
