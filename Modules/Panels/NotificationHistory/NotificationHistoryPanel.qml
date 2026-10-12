// File: Modules/Panels/NotificationHistory/NotificationHistoryPanel.qml
// =============================================================================
// Notification history panel — scrollable list of past notifications with
// time-range filtering (1h/6h/24h/all), keyboard navigation, inline action
// buttons, swipe-to-dismiss, markdown sanitization, and category tab counts.
//
// Functions:
//   moveSelection(dir)       - Move highlight up/down through the list
//   moveAction(dir)          - Cycle through inline actions on the focused item
//   activateSelection()      - Invoke the default action on the selected notification
//   removeSelection()        - Dismiss/delete the selected notification
//   scrollToItem(index)      - Scroll the list to make an item visible
//   resetFocus()             - Clear selection and return to neutral state
//   recalcRangeCounts()      - Rebuild per-range notification counts
//
// Properties:
//   currentRange             - Active time-range filter index (0=1h..3=all)
//   selectedNotificationIndex - Currently highlighted notification
//   selectedActionIndex      - Currently focused inline action
//   panelPosition            - Computed anchor position string
// =============================================================================

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Notifications
import Quickshell.Wayland
import qs.Commons
import qs.Modules.Cards
import qs.Modules.MainScreen
import qs.Modules.Panels.Settings
import qs.Services.System
import qs.Services.UI
import qs.Widgets

// Notification History panel
SmartPanel {
  id: root

  preferredWidth: Math.round((Settings.data.notifications.enableMarkdown ? 540 : 440) * Style.uiScaleRatio)
  preferredHeight: Math.round((Settings.data.notifications.enableMarkdown ? 640 : 540) * Style.uiScaleRatio)

  onOpened: {
    NotificationService.updateLastSeenTs();
  }

  panelContent: Rectangle {
    id: panelContent
    color: "transparent"
    focus: true

    // Force focus when opened
    Connections {
      target: root
      function onOpened() {
        panelContent.forceActiveFocus();
      }
    }

    Keys.onPressed: event => {
                      // Tab navigation for categories
                      if (event.key === Qt.Key_Tab) {
                        currentRange = (currentRange + 1) % 4;
                        event.accepted = true;
                        return;
                      }

                      if (event.key === Qt.Key_Backtab) { // Shift+Tab
                        currentRange = (currentRange - 1 + 4) % 4;
                        event.accepted = true;
                        return;
                      }

                      // Navigation Up/Down
                      if (checkKey(event, 'up')) {
                        moveSelection(-1);
                        event.accepted = true;
                        return;
                      }
                      if (checkKey(event, 'down')) {
                        moveSelection(1);
                        event.accepted = true;
                        return;
                      }

                      // Action Navigation Left/Right
                      if (checkKey(event, 'left')) {
                        moveAction(-1);
                        event.accepted = true;
                        return;
                      }
                      if (checkKey(event, 'right')) {
                        moveAction(1);
                        event.accepted = true;
                        return;
                      }

                      // Activation (Enter)
                      if (checkKey(event, 'enter')) {
                        activateSelection();
                        event.accepted = true;
                        return;
                      }

                      // Removal (Delete/Remove)
                      if (checkKey(event, 'remove') || event.key === Qt.Key_Delete) {
                        removeSelection();
                        event.accepted = true;
                        return;
                      }
                    }

    function parseActions(actions) {
      try {
        return JSON.parse(actions || "[]");
      } catch (e) {
        return [];
      }
    }

    function moveSelection(dir) {
      var m = NotificationService.historyModel;
      if (!m || m.count === 0)
        return;

      var newIndex = focusIndex;
      var found = false;
      var count = m.count;

      // If no selection yet, start from beginning (or end if up)
      if (focusIndex === -1) {
        if (dir > 0)
          newIndex = -1;
        else
          newIndex = count;
      }

      // Loop to find next visible item
      var loopCount = 0;
      while (loopCount < count) {
        newIndex += dir;

        // Bounds check
        if (newIndex < 0 || newIndex >= count) {
          break; // Stop at edges
        }

        var item = m.get(newIndex);
        if (item && isInCurrentRange(item.timestamp)) {
          found = true;
          break;
        }
        loopCount++;
      }

      if (found) {
        focusIndex = newIndex;
        actionIndex = -1; // Reset action selection
        scrollToItem(focusIndex);
      }
    }

    function moveAction(dir) {
      if (focusIndex === -1)
        return;
      var item = NotificationService.historyModel.get(focusIndex);
      if (!item)
        return;

      var actions = parseActions(item.actionsJson);

      if (actions.length === 0)
        return;

      var newActionIndex = actionIndex + dir;

      // Clamp between -1 (body) and actions.length - 1
      if (newActionIndex < -1)
        newActionIndex = -1;
      if (newActionIndex >= actions.length)
        newActionIndex = actions.length - 1;

      actionIndex = newActionIndex;
    }

    function activateSelection() {
      if (focusIndex === -1)
        return;
      var item = NotificationService.historyModel.get(focusIndex);
      if (!item)
        return;

      if (actionIndex >= 0) {
        var actions = parseActions(item.actionsJson);
        if (actionIndex < actions.length) {
          if (NotificationService.invokeAction(item.id, actions[actionIndex].identifier))
            root.close();
        }
      } else {
        var delegate = notificationColumn.children[focusIndex];
        if (!delegate)
          return;
        if (!(delegate.canExpand || delegate.isExpanded))
          return;

        if (scrollView.expandedId === item.id) {
          scrollView.expandedId = "";
        } else {
          scrollView.expandedId = item.id;
        }
      }
    }

    function removeSelection() {
      if (focusIndex === -1)
        return;
      var item = NotificationService.historyModel.get(focusIndex);
      if (!item)
        return;

      NotificationService.removeFromHistory(item.id);
      // selection updates automatically?
      // If we remove item at index i, the next item becomes index i.
      // So focusIndex is still valid (unless it was last item).
      // But we should re-verify if it exists.
      // Actually NotificationService removal might be async or immediate.
      // If immediate, model count decreases.
      // We might need to clamp focusIndex.
      // Let's handle this in a helper or just let the user navigate again.
      // Better UX: select next available or previous if last.
    }

    function scrollToItem(index) {
      // Find the delegate item
      if (index < 0 || index >= notificationColumn.children.length)
        return;

      var item = notificationColumn.children[index];
      if (item && item.visible) {
        // Use the internal flickable from NScrollView for accurate scrolling
        var flickable = scrollView._internalFlickable;
        if (!flickable || !flickable.contentItem)
          return;

        var pos = flickable.contentItem.mapFromItem(item, 0, 0);
        var itemY = pos.y;
        var itemHeight = item.height;

        var currentContentY = flickable.contentY;
        var viewHeight = flickable.height;

        // Check if above visible area
        if (itemY < currentContentY) {
          flickable.contentY = Math.max(0, itemY - Style.marginM);
        } else
          // Check if below visible area
          if (itemY + itemHeight > currentContentY + viewHeight) {
            flickable.contentY = (itemY + itemHeight) - viewHeight + Style.marginM;
          }
      }
    }

    // Calculate content height based on header + tabs (if visible) + content
    property real calculatedHeight: {
      if (NotificationService.historyModel.count === 0) {
        return headerBox.implicitHeight + scrollView.implicitHeight + Style.margin2L + Style.marginM;
      }
      return headerBox.implicitHeight + scrollView.implicitHeight + Style.margin2L + Style.marginM;
    }
    property real contentPreferredHeight: Math.min(root.preferredHeight, Math.ceil(calculatedHeight))

    property real layoutWidth: Math.max(1, root.preferredWidth - Style.margin2L)

    // State (lazy-loaded with panelContent)
    property var rangeCounts: [0, 0, 0, 0]
    property var lastKnownDate: null  // Track the current date to detect day changes

    // UI state (lazy-loaded with panelContent)
    // 0 = All, 1 = Today, 2 = Yesterday, 3 = Earlier
    property int currentRange: 1  // start on Today by default
    property bool groupByDate: true
    onCurrentRangeChanged: resetFocus()

    // Keyboard navigation state
    property int focusIndex: -1
    property int actionIndex: -1  // For actions within a notification

    function resetFocus() {
      focusIndex = -1;
      actionIndex = -1;
    }

    function checkKey(event, settingName) {
      return Keybinds.checkKey(event, settingName, Settings);
    }

    // Helper functions (lazy-loaded with panelContent)
    function dateOnly(d) {
      return new Date(d.getFullYear(), d.getMonth(), d.getDate());
    }

    function getDateKey(d) {
      // Returns a string key for the date (YYYY-MM-DD) for comparison
      var date = dateOnly(d);
      return date.getFullYear() + "-" + date.getMonth() + "-" + date.getDate();
    }

    function rangeForTimestamp(ts) {
      var dt = new Date(ts);
      var today = dateOnly(new Date());
      var thatDay = dateOnly(dt);

      var diffMs = today - thatDay;
      var diffDays = Math.floor(diffMs / (1000 * 60 * 60 * 24));

      if (diffDays === 0)
        return 0;
      if (diffDays === 1)
        return 1;
      return 2;
    }

    function recalcRangeCounts() {
      var m = NotificationService.historyModel;
      if (!m || typeof m.count === "undefined" || m.count <= 0) {
        panelContent.rangeCounts = [0, 0, 0, 0];
        return;
      }

      var counts = [0, 0, 0, 0];

      counts[0] = m.count;

      for (var i = 0; i < m.count; ++i) {
        var item = m.get(i);
        if (!item || typeof item.timestamp === "undefined")
          continue;
        var r = rangeForTimestamp(item.timestamp);
        counts[r + 1] = counts[r + 1] + 1;
      }

      panelContent.rangeCounts = counts;
    }

    function isInCurrentRange(ts) {
      if (currentRange === 0)
        return true;
      return rangeForTimestamp(ts) === (currentRange - 1);
    }

    function countForRange(range) {
      return rangeCounts[range] || 0;
    }

    function hasNotificationsInCurrentRange() {
      var m = NotificationService.historyModel;
      if (!m || m.count === 0) {
        return false;
      }
      for (var i = 0; i < m.count; ++i) {
        var item = m.get(i);
        if (item && isInCurrentRange(item.timestamp))
          return true;
      }
      return false;
    }

    Component.onCompleted: {
      recalcRangeCounts();
      // Initialize lastKnownDate
      lastKnownDate = getDateKey(new Date());
    }

    Connections {
      target: NotificationService.historyModel
      function onCountChanged() {
        panelContent.recalcRangeCounts();
      }
    }

    // Timer to check for day changes at midnight
    Timer {
      id: dayChangeTimer
      interval: 60000  // Check every minute
      repeat: true
      running: true  // Always runs when panelContent exists (panel is open)
      onTriggered: {
        var currentDateKey = panelContent.getDateKey(new Date());
        if (panelContent.lastKnownDate !== null && panelContent.lastKnownDate !== currentDateKey) {
          // Day has changed, recalculate counts
          panelContent.recalcRangeCounts();
        }
        panelContent.lastKnownDate = currentDateKey;
      }
    }

    ColumnLayout {
      id: mainColumn
      anchors.fill: parent
      anchors.margins: Style.marginL
      spacing: Style.marginM

      // Header section
      NBox {
        id: headerBox
        Layout.fillWidth: true
        implicitHeight: header.implicitHeight + Style.margin2M

        ColumnLayout {
          id: header
          anchors.fill: parent
          anchors.margins: Style.marginM
          spacing: Style.marginM

          RowLayout {
            id: headerRow
            NIcon {
              icon: "bell"
              pointSize: Style.fontSizeXXL
              color: Color.mPrimary
            }

            NText {
              text: "Notifications"
              pointSize: Style.fontSizeL
              font.weight: Style.fontWeightBold
              color: Color.mOnSurface
              Layout.fillWidth: true
            }

            NIconButton {
              icon: NotificationService.doNotDisturb ? "bell-off" : "bell"
              tooltipText: NotificationService.doNotDisturb ? "Do Not Disturb" : "Do Not Disturb"
              baseSize: Style.baseWidgetSize * 0.8
              onClicked: NotificationService.doNotDisturb = !NotificationService.doNotDisturb
            }

            NIconButton {
              icon: "trash"
              tooltipText: "Clear history"
              baseSize: Style.baseWidgetSize * 0.8
              onClicked: {
                NotificationService.clearHistory();
                // Close panel as there is nothing more to see.
                root.close();
              }
            }

            NIconButton {
              icon: "settings"
              tooltipText: "Settings"
              baseSize: Style.baseWidgetSize * 0.8
              onClicked: {
                SettingsPanelService.openToTab(SettingsPanel.Tab.Notifications, 0, screen);
                root.close();
              }
            }
          }

          // Time range tabs ([All] / [Today] / [Yesterday] / [Earlier])
          NTabBar {
            id: tabsBox
            Layout.fillWidth: true
            visible: NotificationService.historyModel.count > 0 && panelContent.groupByDate
            currentIndex: panelContent.currentRange
            tabHeight: Style.toOdd(Style.baseWidgetSize * 0.8)
            spacing: Style.marginXS
            distributeEvenly: true

            NTabButton {
              tabIndex: 0
              text: "All" + " (" + panelContent.countForRange(0) + ")"
              checked: tabsBox.currentIndex === 0
              onClicked: panelContent.currentRange = 0
              pointSize: Style.fontSizeXS
            }

            NTabButton {
              tabIndex: 1
              text: "Today" + " (" + panelContent.countForRange(1) + ")"
              checked: tabsBox.currentIndex === 1
              onClicked: panelContent.currentRange = 1
              pointSize: Style.fontSizeXS
            }

            NTabButton {
              tabIndex: 2
              text: "Yesterday" + " (" + panelContent.countForRange(2) + ")"
              checked: tabsBox.currentIndex === 2
              onClicked: panelContent.currentRange = 2
              pointSize: Style.fontSizeXS
            }

            NTabButton {
              tabIndex: 3
              text: "Earlier" + " (" + panelContent.countForRange(3) + ")"
              checked: tabsBox.currentIndex === 3
              onClicked: panelContent.currentRange = 3
              pointSize: Style.fontSizeXS
            }
          }
        }
      }

      // Notification list container with gradient overlay
      Item {
        Layout.fillWidth: true
        Layout.fillHeight: true

        NScrollView {
          id: scrollView
          anchors.fill: parent
          horizontalPolicy: ScrollBar.AlwaysOff
          verticalPolicy: ScrollBar.AsNeeded
          reserveScrollbarSpace: false
          // The row's own fill, so the fade blends into it instead of a stale token.
          gradientColor: Qt.alpha(Color.mSurfaceContainer, Color.adaptiveOpacity(Settings.data.notifications.backgroundOpacity) || 1.0)

          // Track which notification is expanded
          property string expandedId: ""

          ColumnLayout {
            width: panelContent.layoutWidth
            spacing: Style.marginM

            // Empty state when no notifications
            NBox {
              visible: !panelContent.hasNotificationsInCurrentRange()
              Layout.fillWidth: true
              Layout.preferredHeight: emptyState.implicitHeight + Style.marginXL

              ColumnLayout {
                id: emptyState
                anchors.fill: parent
                anchors.margins: Style.marginM
                spacing: Style.marginM

                Item {
                  Layout.fillHeight: true
                }

                NIcon {
                  icon: "bell-off"
                  pointSize: (NotificationService.historyModel.count === 0) ? 48 : Style.baseWidgetSize
                  color: Color.mOnSurfaceVariant
                  Layout.alignment: Qt.AlignHCenter
                }

                NText {
                  text: "No notifications"
                  pointSize: (NotificationService.historyModel.count === 0) ? Style.fontSizeL : Style.fontSizeM
                  color: Color.mOnSurfaceVariant
                  Layout.alignment: Qt.AlignHCenter
                }

                NText {
                  visible: NotificationService.historyModel.count === 0
                  text: "Your notifications will show up here as they arrive."
                  pointSize: Style.fontSizeS
                  color: Color.mOnSurfaceVariant
                  horizontalAlignment: Text.AlignHCenter
                  Layout.fillWidth: true
                  wrapMode: Text.WordWrap
                }

                Item {
                  Layout.fillHeight: true
                }
              }
            }

            // Notification list container
            Item {
              visible: panelContent.hasNotificationsInCurrentRange()
              Layout.fillWidth: true
              Layout.preferredHeight: notificationColumn.implicitHeight

              Column {
                id: notificationColumn
                width: panelContent.layoutWidth
                // Rows inset their card by Style.cardShadowPadding; cancelling that
                // here reproduces the popup's marginM gap between the visible cards.
                spacing: -Style.cardShadowPadding * 2 + Style.marginM

                Repeater {
                  model: NotificationService.historyModel

                  delegate: NotificationListItem {
                    width: parent.width
                    listIndex: index
                    inCurrentRange: panelContent.isInCurrentRange(model.timestamp)
                    isExpanded: scrollView.expandedId === model.id
                    focusIndex: panelContent.focusIndex
                    actionIndex: panelContent.actionIndex
                    notificationId: model.id
                    appName: model.appName || ""
                    summary: model.summary
                    body: model.body
                    summaryMarkdown: model.summaryMarkdown
                    bodyMarkdown: model.bodyMarkdown
                    urgency: model.urgency
                    timestamp: model.timestamp
                    actionsJson: model.actionsJson
                    cachedImage: model.cachedImage
                    originalImage: model.originalImage

                    // `root` is this panel's SmartPanel; the row owns no panel state.
                    onActionInvoked: root.close()
                    onRequestFocus: idx => panelContent.focusIndex = idx
                    onRequestClearAction: panelContent.actionIndex = -1
                    onRequestToggleExpand: scrollView.expandedId = scrollView.expandedId === model.id ? "" : model.id
                  }
                }
              }
            }
          }
        }
      }
    }
  }
}
