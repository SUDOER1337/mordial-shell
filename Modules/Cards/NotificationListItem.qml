// File: Modules/Cards/NotificationListItem.qml
// =============================================================================
// One row of a notification list. Shared by the Notification History panel
// (Modules/Panels/NotificationHistory/NotificationHistoryPanel.qml) and the
// dashboard's notification card (Modules/Cards/NotificationCard.qml) so both
// render identical rows.
//
// The card itself (fill, border, radius, shadow) is a copy of the one in the
// standalone notification window (Modules/Notification/Notification.qml), so a
// row looks like the notification that just arrived. That card is inset by
// `shadowPadding` inside this row; owners stacking rows must therefore use
// `-2 * Style.cardShadowPadding + Style.marginM` as their column spacing to
// land on the popup's marginM gap between visible cards.
//
// Functions:
//   parseActions(actions) - Safely JSON-parse a notification's action array
//   linkAtPoint(x, y)     - Resolve a click point to an inline action link
//   updateCursorAt(x, y)  - Point the cursor at a link when hovered
//   dismissBySwipe()      - Dismiss the row once swiped past the threshold
//
// Signals (the row owns no state the list needs to know about):
//   actionInvoked()       - An action succeeded; the owner may close itself
//   requestFocus(index)   - Owner should move keyboard focus to this row
//   requestClearAction()  - Owner should clear its inline action selection
//   requestToggleExpand() - Owner should toggle this row's expanded state
// =============================================================================

import QtQuick
import qs.Commons
import qs.Services.System
import qs.Widgets

Item {
  id: root

  // === Supplied by the list that owns this row ===
  property int listIndex: -1
  property int focusIndex: -1
  property int actionIndex: -1
  property bool inCurrentRange: true
  property bool isExpanded: false

  // === Notification fields (roles from NotificationService.historyModel) ===
  property string notificationId: ""
  property string appName: ""
  property string summary: ""
  property string body: ""
  property string summaryMarkdown: ""
  property string bodyMarkdown: ""
  property int urgency: 0
  property real timestamp: 0
  property string actionsJson: "[]"
  property string cachedImage: ""
  property string originalImage: ""

  signal actionInvoked
  signal requestFocus(int index)
  signal requestClearAction
  signal requestToggleExpand

  // Parse the action array defensively: history entries are written by
  // external apps, so a malformed value must not break the whole list.
  function parseActions(actions) {
    try {
      return JSON.parse(actions || "[]");
    } catch (e) {
      return [];
    }
  }
  visible: root.inCurrentRange
  height: visible && !isRemoving ? contentColumn.height + Style.margin2M + root.shadowPadding * 2 : 0

  property bool canExpand: summaryText.truncated || bodyText.truncated
  property real swipeOffset: 0
  property real pressGlobalX: 0
  property real pressGlobalY: 0
  property bool isSwiping: false
  property bool isRemoving: false
  property string pendingLink: ""
  readonly property real swipeStartThreshold: Math.round(16 * Style.uiScaleRatio)
  readonly property real swipeDismissThreshold: Math.max(110, width * 0.3)
  readonly property int removeAnimationDuration: Style.animationNormal
  readonly property int notificationTextFormat: (Settings.data.notifications.enableMarkdown && root.isExpanded) ? Text.MarkdownText : Text.StyledText
  readonly property real actionButtonSize: Style.baseWidgetSize * 0.7
  readonly property real buttonClusterWidth: root.actionButtonSize * 2 + Style.marginXS
  readonly property real iconSize: Math.round(40 * Style.uiScaleRatio)

  // === Card chrome, kept identical to the standalone notification window ===
  // The card is inset by the shadow padding inside this row, so list owners must
  // offset it back out with negative column spacing to keep a marginM gap between
  // the visible cards (see Modules/Notification/Notification.qml).
  readonly property int shadowPadding: Style.cardShadowPadding
  // Same fill/border alpha the popup card and toasts use, so a row reads as the
  // notification the user already sees over the desktop.
  readonly property real backgroundAlpha: Color.adaptiveOpacity(Settings.data.notifications.backgroundOpacity) || 1.0

  function isSafeLink(link) {
    if (!link)
      return false;
    const lower = link.toLowerCase();
    const schemes = ["http://", "https://", "mailto:"];
    return schemes.some(scheme => lower.startsWith(scheme));
  }

  function linkAtPoint(x, y) {
    if (!Settings.data.notifications.enableMarkdown || !root.isExpanded)
      return "";

    if (summaryText) {
      const summaryPoint = summaryText.mapFromItem(historyInteractionArea, x, y);
      if (summaryPoint.x >= 0 && summaryPoint.y >= 0 && summaryPoint.x <= summaryText.width && summaryPoint.y <= summaryText.height) {
        const summaryLink = summaryText.linkAt ? summaryText.linkAt(summaryPoint.x, summaryPoint.y) : "";
        if (isSafeLink(summaryLink))
          return summaryLink;
      }
    }

    if (bodyText) {
      const bodyPoint = bodyText.mapFromItem(historyInteractionArea, x, y);
      if (bodyPoint.x >= 0 && bodyPoint.y >= 0 && bodyPoint.x <= bodyText.width && bodyPoint.y <= bodyText.height) {
        const bodyLink = bodyText.linkAt ? bodyText.linkAt(bodyPoint.x, bodyPoint.y) : "";
        if (isSafeLink(bodyLink))
          return bodyLink;
      }
    }

    return "";
  }

  function updateCursorAt(x, y) {
    if (root.isExpanded && root.linkAtPoint(x, y)) {
      historyInteractionArea.cursorShape = Qt.PointingHandCursor;
    } else {
      historyInteractionArea.cursorShape = Qt.ArrowCursor;
    }
  }

  transform: Translate {
    x: root.swipeOffset
  }

  function dismissBySwipe() {
    if (isRemoving)
      return;
    isRemoving = true;
    isSwiping = false;

    if (Settings.data.general.animationDisabled) {
      NotificationService.removeFromHistory(notificationId);
      return;
    }

    swipeOffset = swipeOffset >= 0 ? width + Style.marginL : -width - Style.marginL;
    opacity = 0;
    removeTimer.restart();
  }

  Timer {
    id: removeTimer
    interval: root.removeAnimationDuration
    repeat: false
    onTriggered: NotificationService.removeFromHistory(notificationId)
  }

  Behavior on swipeOffset {
    enabled: !Settings.data.general.animationDisabled && !root.isSwiping
    NumberAnimation {
      duration: root.removeAnimationDuration
      easing.type: Easing.OutCubic
    }
  }

  Behavior on opacity {
    enabled: !Settings.data.general.animationDisabled && root.isRemoving
    NumberAnimation {
      duration: root.removeAnimationDuration
      easing.type: Easing.OutCubic
    }
  }

  Behavior on height {
    enabled: !Settings.data.general.animationDisabled && root.isRemoving
    NumberAnimation {
      duration: root.removeAnimationDuration
      easing.type: Easing.OutCubic
    }
  }

  Behavior on y {
    enabled: !Settings.data.general.animationDisabled && root.isRemoving
    NumberAnimation {
      duration: root.removeAnimationDuration
      easing.type: Easing.OutCubic
    }
  }

  // Parse actions safely
  property var actionsList: parseActions(actionsJson)

  readonly property bool isFocused: root.listIndex === root.focusIndex

  Rectangle {
    id: cardBackground
    anchors.fill: parent
    anchors.margins: root.shadowPadding
    radius: Style.radiusL
    color: Qt.alpha(Color.mSurfaceContainer, root.backgroundAlpha)
    border.color: {
      if (root.isFocused)
        return Color.mPrimary;
      return Qt.alpha(Color.mOutline, root.backgroundAlpha);
    }
    border.width: root.isFocused ? Style.borderM : Style.borderS

    Behavior on color {
      enabled: !Settings.data.general.animationDisabled
      ColorAnimation {
        duration: Style.animationFast
      }
    }
  }

  NDropShadow {
    anchors.fill: cardBackground
    source: cardBackground
    autoPaddingEnabled: true
  }

  // Click to expand/collapse
  MouseArea {
    id: historyInteractionArea
    anchors.fill: cardBackground
    anchors.rightMargin: root.buttonClusterWidth + Style.marginM
    enabled: !root.isRemoving
    hoverEnabled: true
    cursorShape: Qt.ArrowCursor
    onPressed: mouse => {
                 root.requestFocus(root.listIndex);
                 root.requestClearAction();

                 if (root.isExpanded) {
                   const link = root.linkAtPoint(mouse.x, mouse.y);
                   if (link) {
                     root.pendingLink = link;
                   } else {
                     root.pendingLink = "";
                   }
                 }

                 if (mouse.button !== Qt.LeftButton)
                 return;
                 const globalPoint = historyInteractionArea.mapToGlobal(mouse.x, mouse.y);
                 root.pressGlobalX = globalPoint.x;
                 root.pressGlobalY = globalPoint.y;
                 root.isSwiping = false;
               }
    onPositionChanged: mouse => {
                         if (!(mouse.buttons & Qt.LeftButton) || root.isRemoving)
                         return;

                         const globalPoint = historyInteractionArea.mapToGlobal(mouse.x, mouse.y);
                         const deltaX = globalPoint.x - root.pressGlobalX;
                         const deltaY = globalPoint.y - root.pressGlobalY;

                         if (!root.isSwiping) {
                           if (Math.abs(deltaX) < root.swipeStartThreshold)
                           return;

                           // Only start a swipe-dismiss when horizontal movement is dominant.
                           if (Math.abs(deltaX) <= Math.abs(deltaY) * 1.15) {
                             return;
                           }
                           root.isSwiping = true;
                         }

                         if (root.pendingLink && Math.abs(deltaX) >= root.swipeStartThreshold) {
                           root.pendingLink = "";
                         }

                         root.swipeOffset = deltaX;
                       }
    onReleased: mouse => {
                  if (mouse.button !== Qt.LeftButton)
                  return;

                  if (root.isSwiping) {
                    if (Math.abs(root.swipeOffset) >= root.swipeDismissThreshold) {
                      root.dismissBySwipe();
                    } else {
                      root.swipeOffset = 0;
                    }
                    root.isSwiping = false;
                    root.pendingLink = "";
                    return;
                  }

                  if (root.pendingLink) {
                    Qt.openUrlExternally(root.pendingLink);
                    root.pendingLink = "";
                    return;
                  }

                  // Without a default action, or if invoking it fails,
                  // fall back to focusing the sender window by app identity.
                  var actions = root.actionsList;
                  var hasDefault = actions.some(function (a) {
                    return a.identifier === "default";
                  });
                  if (hasDefault && NotificationService.invokeAction(root.notificationId, "default")) {
                    root.actionInvoked();
                  } else {
                    NotificationService.focusSenderWindow(root.appName);
                    root.actionInvoked();
                  }
                }
    onCanceled: {
      root.isSwiping = false;
      root.swipeOffset = 0;
      root.pendingLink = "";
      historyInteractionArea.cursorShape = Qt.ArrowCursor;
    }
  }

  HoverHandler {
    target: historyInteractionArea
    onPointChanged: root.updateCursorAt(point.position.x, point.position.y)
    onActiveChanged: {
      if (!active) {
        historyInteractionArea.cursorShape = Qt.ArrowCursor;
      }
    }
  }

  onVisibleChanged: {
    if (!visible) {
      root.isSwiping = false;
      root.swipeOffset = 0;
      root.opacity = 1;
      root.isRemoving = false;
      removeTimer.stop();
    }
  }

  Component.onDestruction: removeTimer.stop()

  Column {
    id: contentColumn
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: parent.top
    // The extra shadowPadding lines the content up with the inset card.
    anchors.margins: Style.marginM + root.shadowPadding
    spacing: Style.marginM

    Row {
      width: parent.width
      spacing: Style.marginM

      // Icon
      NImageRounded {
        anchors.verticalCenter: root.isExpanded ? undefined : parent.verticalCenter
        width: root.iconSize
        height: root.iconSize
        radius: Math.min(Style.radiusL, width / 2)
        imagePath: cachedImage || originalImage || ""
        borderColor: "transparent"
        borderWidth: 0
        fallbackIcon: "bell"
        fallbackIconSize: 24
      }

      // Content
      Column {
        width: parent.width - root.iconSize - root.buttonClusterWidth - Style.margin2M
        spacing: Style.marginXS

        // Header row with app name and timestamp
        Row {
          width: parent.width
          spacing: Style.marginS

          // Urgency indicator
          Rectangle {
            width: 6
            height: 6
            anchors.verticalCenter: parent.verticalCenter
            radius: 3
            visible: urgency !== 1
            color: {
              if (urgency === 2)
                return Color.mError;
              else if (urgency === 0)
                return Color.mOnSurfaceVariant;
              else
                return "transparent";
            }
          }

          NText {
            text: appName || "Unknown App"
            pointSize: Style.fontSizeXS
            font.weight: Style.fontWeightBold
            color: Color.mSecondary
          }

          NText {
            textFormat: Text.PlainText
            text: " " + Time.formatRelativeTime(timestamp)
            pointSize: Style.fontSizeXXS
            color: Color.mOnSurfaceVariant
            anchors.bottom: parent.bottom
          }
        }

        // Summary
        NText {
          id: summaryText
          width: parent.width
          text: (Settings.data.notifications.enableMarkdown && root.isExpanded) ? (summaryMarkdown || "No summary") : (summary || "No summary")
          pointSize: Style.fontSizeM
          color: Color.mOnSurface
          textFormat: root.notificationTextFormat
          wrapMode: Text.Wrap
          maximumLineCount: root.isExpanded ? 999 : 2
          elide: Text.ElideRight
        }

        // Body
        NText {
          id: bodyText
          width: parent.width
          text: (Settings.data.notifications.enableMarkdown && root.isExpanded) ? (bodyMarkdown || "") : (body || "")
          pointSize: Style.fontSizeS
          color: Color.mOnSurfaceVariant
          textFormat: root.notificationTextFormat
          wrapMode: Text.Wrap
          maximumLineCount: root.isExpanded ? 999 : 3
          elide: Text.ElideRight
          visible: text.length > 0
        }

        // Actions Flow
        Flow {
          width: parent.width
          spacing: Style.marginS
          visible: root.actionsList.length > 0

          Repeater {
            model: root.actionsList

            delegate: NButton {
              text: modelData.text
              fontSize: Style.fontSizeS

              readonly property bool actionNavActive: root.isFocused && root.actionIndex !== -1
              readonly property bool isSelected: actionNavActive && root.actionIndex === index

              backgroundColor: isSelected ? Color.mSecondary : Color.mPrimary
              textColor: isSelected ? Color.mOnSecondary : Color.mOnPrimary

              outlined: false
              implicitHeight: 24

              onHoveredChanged: {
                if (hovered) {
                  root.requestFocus(root.listIndex);
                }
              }

              // Capture modelData in a property to avoid reference errors
              property var actionData: modelData
              onClicked: {
                if (NotificationService.invokeAction(root.notificationId, actionData.identifier))
                  root.actionInvoked();
              }
            }
          }
        }
      }

      Item {
        width: root.buttonClusterWidth
        height: root.actionButtonSize

        Row {
          anchors.right: parent.right
          spacing: Style.marginXS

          NIconButton {
            id: expandButton
            icon: root.isExpanded ? "chevron-up" : "chevron-down"
            tooltipText: root.isExpanded ? "Click to collapse" || "Click to collapse" : "Click to expand" || "Click to expand"
            baseSize: root.actionButtonSize
            opacity: (root.canExpand || root.isExpanded) ? 1.0 : 0.0
            enabled: root.canExpand || root.isExpanded

            onClicked: {
              root.pendingLink = "";
              historyInteractionArea.cursorShape = Qt.ArrowCursor;
              root.requestToggleExpand();
            }
          }

          // Delete button
          NIconButton {
            icon: "trash"
            tooltipText: "Delete notification"
            baseSize: root.actionButtonSize

            onClicked: {
              NotificationService.removeFromHistory(notificationId);
            }
          }
        }
      }
    }
  }
}
