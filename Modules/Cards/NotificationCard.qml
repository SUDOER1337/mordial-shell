// File: Modules/Cards/NotificationCard.qml
// =============================================================================
// Dashboard column that lists notification history, reusing the same
// NotificationListItem rows as the Notification History panel so both surfaces
// stay visually identical. Unlike the panel this card has no date-range
// filtering and no keyboard focus: it is a read-only overview that updates live
// as notifications arrive.
//
// Functions:
//   clearAll() - Remove every entry from notification history
// =============================================================================

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Commons
import qs.Services.System
import qs.Widgets

NBox {
  id: root

  readonly property int count: NotificationService.historyModel.count
  property string expandedId: ""

  implicitHeight: content.implicitHeight + Style.margin2M
  // Fills the height the Dashboard column layout assigns to this card.
  Layout.fillHeight: true
  Layout.preferredWidth: 320

  /** Empty every history entry from the card's header. */
  function clearAll() {
    NotificationService.clearHistory();
  }

  ColumnLayout {
    id: content
    anchors.fill: parent
    anchors.margins: Style.marginM
    spacing: Style.marginM

    // === Header ===
    RowLayout {
      Layout.fillWidth: true
      spacing: Style.marginM

      NIcon {
        icon: "bell"
        pointSize: Style.fontSizeL
        color: Color.mPrimary
      }

      NText {
        text: "Notifications"
        pointSize: Style.fontSizeM
        font.weight: Style.fontWeightBold
        color: Color.mOnSurface
        Layout.fillWidth: true
        elide: Text.ElideRight
      }

      NIconButton {
        icon: NotificationService.doNotDisturb ? "bell-off" : "bell"
        tooltipText: "Do Not Disturb"
        baseSize: Style.baseWidgetSize * 0.8
        onClicked: NotificationService.doNotDisturb = !NotificationService.doNotDisturb
      }

      NIconButton {
        icon: "trash"
        tooltipText: "Clear All"
        baseSize: Style.baseWidgetSize * 0.8
        visible: root.count > 0
        onClicked: root.clearAll()
      }
    }

    // === Empty state ===
    ColumnLayout {
      visible: root.count === 0
      Layout.fillWidth: true
      Layout.fillHeight: true
      spacing: Style.marginM

      NIcon {
        icon: "bell-off"
        pointSize: Style.baseWidgetSize
        color: Color.mOnSurfaceVariant
        Layout.alignment: Qt.AlignHCenter
      }

      NText {
        text: "No notifications"
        pointSize: Style.fontSizeM
        color: Color.mOnSurfaceVariant
        Layout.alignment: Qt.AlignHCenter
      }

      NText {
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

    // === History list ===
    NScrollView {
      id: listScroll
      visible: root.count > 0
      Layout.fillWidth: true
      Layout.fillHeight: true
      horizontalPolicy: ScrollBar.AlwaysOff
      // The row's own fill, so the fade blends into it instead of a stale token.
      gradientColor: Qt.alpha(Color.mSurfaceContainer, Color.adaptiveOpacity(Settings.data.notifications.backgroundOpacity) || 1.0)
      reserveScrollbarSpace: false

      Column {
        id: notificationColumn
        width: listScroll.availableWidth
        // Rows inset their card by Style.cardShadowPadding; cancelling that here
        // reproduces the popup's marginM gap between the visible cards.
        spacing: -Style.cardShadowPadding * 2 + Style.marginM

        Repeater {
          model: NotificationService.historyModel

          delegate: NotificationListItem {
            width: notificationColumn.width

            // The card is not keyboard-focusable, so no row is ever focused and
            // the inline action navigator stays inactive.
            listIndex: index
            inCurrentRange: true
            isExpanded: root.expandedId === notificationId
            actionIndex: -1

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

            // A dashboard card stays open when a notification is acted on.
            onRequestToggleExpand: root.expandedId = root.expandedId === notificationId ? "" : notificationId
          }
        }
      }
    }
  }
}
