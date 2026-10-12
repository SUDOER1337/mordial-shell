import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import "MarkdownRenderer.js" as MarkdownRenderer
import qs.Commons
import qs.Services.UI
import qs.Widgets

Item {
  id: root
  signal requestTabCycleForward
  signal requestTabCycleBackward
  signal requestSettings

  property var mainInstance: null

  // State from main instance
  readonly property var messages: mainInstance?.messages || []
  readonly property bool isGenerating: mainInstance?.isGenerating || false
  readonly property string currentResponse: mainInstance?.currentResponse || ""
  readonly property string errorMessage: mainInstance?.errorMessage || ""
  readonly property bool isSearchingWeb: mainInstance?.isSearchingWeb || false
  readonly property bool isRephrasing: mainInstance?.isRephrasing || false
  property string initialInputText: mainInstance?.chatInputText || ""
  property int initialCursorPosition: mainInstance?.chatInputCursorPosition || 0

  // Active provider model info (computed from mainInstance)
  readonly property string model: mainInstance?.model || ""
  readonly property var availableModels: mainInstance?.availableModels || []
  readonly property bool isLoadingModels: mainInstance?.isLoadingModels || false
  readonly property string activeProvider: mainInstance?.activeProvider || "ollama"

  ColumnLayout {
    anchors.fill: parent
    spacing: Style.marginM

    // Header with model selector
    RowLayout {
      Layout.fillWidth: true
      spacing: Style.marginS

      NIcon {
        icon: "sparkles"
        color: Color.mPrimary
        pointSize: Style.fontSizeM
        applyUiScale: false
      }

      // Provider indicator
      Rectangle {
        Layout.preferredWidth: providerLabel.width + Style.marginM * 2
        Layout.preferredHeight: providerLabel.height + Style.marginS * 2
        color: root.activeProvider === "ollama" ? "#00AA00" : "#0066CC"
        radius: Style.radiusS
        opacity: 0.9

        NText {
          id: providerLabel
          anchors.centerIn: parent
          text: root.activeProvider === "ollama" ? "Ollama" : "LM Studio"
          color: "white"
          pointSize: Style.fontSizeXS
          font.weight: Font.Bold
        }
      }

      // Model selector
      NComboBox {
        Layout.fillWidth: true
        model: {
          var items = [];
          for (var i = 0; i < availableModels.length; i++) {
            items.push({
                         "key": availableModels[i],
                         "name": availableModels[i]
                       });
          }
          // Keep current model visible even if it is not in the fetched list yet.
          if (root.model && root.model !== "" && availableModels.indexOf(root.model) === -1) {
            items.unshift({
                            "key": root.model,
                            "name": root.model
                          });
          }
          return items;
        }
        currentKey: root.model
        onSelected: function (key) {
          if (mainInstance && mainInstance.changeModel) {
            mainInstance.changeModel(key);
          }
        }
        enabled: !isLoadingModels && availableModels.length > 0
      }

      // Web search indicator
      NText {
        text: {
          if (root.isRephrasing)
            return "Rephrasing...";
          if (root.isSearchingWeb)
            return "Searching web...";
          return "";
        }
        color: Color.mPrimary
        pointSize: Style.fontSizeXS
        visible: root.isRephrasing || root.isSearchingWeb
      }

      // Web search spinner
      NIcon {
        icon: "loader-2"
        visible: root.isRephrasing || root.isSearchingWeb
        color: Color.mPrimary
        pointSize: Style.fontSizeS
        applyUiScale: false

        RotationAnimation on rotation {
          from: 0
          to: 360
          duration: 1000
          loops: Animation.Infinite
          running: root.isRephrasing || root.isSearchingWeb
        }
      }

      // Loading indicator (model list)
      NIcon {
        icon: "loader-2"
        visible: isLoadingModels
        color: Color.mPrimary
        pointSize: Style.fontSizeS
        applyUiScale: false

        RotationAnimation on rotation {
          from: 0
          to: 360
          duration: 1000
          loops: Animation.Infinite
          running: isLoadingModels
        }
      }

      // Refresh models button
      NIconButton {
        icon: "refresh"
        colorFg: Color.mOnSurfaceVariant
        tooltipText: "Refresh Models"
        onClicked: {
          if (mainInstance) {
            if (root.activeProvider === "ollama" && mainInstance.loadOllamaModels) {
              mainInstance.loadOllamaModels();
            } else if (root.activeProvider === "lmstudio" && mainInstance.loadLmStudioModels) {
              mainInstance.loadLmStudioModels();
            }
          }
        }
      }

      NIconButton {
        icon: "settings"
        colorFg: Color.mOnSurfaceVariant
        tooltipText: "AI Chat Settings"
        onClicked: root.requestSettings()
      }

      // Clear history
      NText {
        id: clearHistoryText
        text: "Clear History"
        property bool enabledClear: messages.length > 0 && !isGenerating
        property bool hovered: false
        color: enabledClear ? (hovered ? Color.mOnSurface : Color.mOnSurfaceVariant) : Color.mOnSurfaceVariant
        pointSize: Style.fontSizeXS
        font.weight: hovered ? Font.Medium : Font.Normal
        opacity: enabledClear ? 1.0 : 0.5
        Layout.alignment: Qt.AlignRight

        MouseArea {
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          enabled: clearHistoryText.enabledClear
          onEntered: clearHistoryText.hovered = true
          onExited: clearHistoryText.hovered = false
          onClicked: {
            if (mainInstance)
              mainInstance.clearMessages();
          }
        }
      }
    }

    // Messages area
    Rectangle {
      Layout.fillWidth: true
      Layout.fillHeight: true
      color: Color.mSurface
      radius: Style.radiusM
      clip: true

      // Empty state
      Item {
        anchors.fill: parent
        visible: messages.length === 0 && !isGenerating

        ColumnLayout {
          anchors.centerIn: parent
          spacing: Style.marginM

          NIcon {
            Layout.alignment: Qt.AlignHCenter
            icon: "sparkles"
            color: Color.mOnSurfaceVariant
            pointSize: Style.fontSizeXXL * 2
            applyUiScale: false
          }

          NText {
            Layout.alignment: Qt.AlignHCenter
            text: "Start a conversation"
            color: Color.mOnSurfaceVariant
            pointSize: Style.fontSizeM
            font.weight: Font.Medium
          }

          NText {
            Layout.alignment: Qt.AlignHCenter
            text: "Type a message below to begin"
            color: Color.mOnSurfaceVariant
            pointSize: Style.fontSizeS
          }
        }
      }

      // Chat messages
      Flickable {
        id: chatFlickable
        anchors.fill: parent
        anchors.margins: Style.marginS
        contentWidth: width
        contentHeight: messageColumn.height
        clip: true

        property bool autoScrollEnabled: true

        readonly property bool isNearBottom: {
          if (contentHeight <= height)
            return true;
          return contentY >= contentHeight - height - 30;
        }

        function scrollToBottom() {
          if (contentHeight > height) {
            contentY = contentHeight - height;
          }
        }

        onContentHeightChanged: {
          if (autoScrollEnabled && contentHeight > height) {
            scrollToBottom();
          }
        }

        onMovementEnded: {
          autoScrollEnabled = isNearBottom;
        }

        Column {
          id: messageColumn
          width: parent.width
          spacing: Style.marginM

          Repeater {
            model: messages
            delegate: MessageBubble {
              width: messageColumn.width
              message: modelData
            }
          }

          // Streaming message
          Rectangle {
            id: streamingBubble
            width: parent.width
            color: "transparent"
            visible: isGenerating && currentResponse.trim() !== ""

            MessageBubble {
              width: parent.width
              message: ({
                          "id": "streaming",
                          "role": "assistant",
                          "content": currentResponse,
                          "timestamp": new Date().toISOString()
                        })
            }
          }
        }
      }

      // Scroll to bottom button
      Rectangle {
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: Style.marginM
        width: 32
        height: 32
        radius: width / 2
        color: Color.mPrimary
        visible: !chatFlickable.autoScrollEnabled && messages.length > 0
        opacity: scrollButtonMouse.containsMouse ? 1.0 : 0.8

        NIcon {
          anchors.centerIn: parent
          icon: "chevron-down"
          color: Color.mOnPrimary
          pointSize: Style.fontSizeM
          applyUiScale: false
        }

        MouseArea {
          id: scrollButtonMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: {
            chatFlickable.autoScrollEnabled = true;
            chatFlickable.scrollToBottom();
          }
        }
      }
    }

    // Error message
    Rectangle {
      Layout.fillWidth: true
      Layout.preferredHeight: errorRow.implicitHeight + Style.marginS * 2
      color: Qt.alpha(Color.mError, 0.2)
      radius: Style.radiusS
      visible: errorMessage !== ""

      RowLayout {
        id: errorRow
        anchors.fill: parent
        anchors.margins: Style.marginS
        spacing: Style.marginS

        NIcon {
          icon: "alert-triangle"
          color: Color.mError
          pointSize: Style.fontSizeM
        }

        NText {
          Layout.fillWidth: true
          text: errorMessage
          color: Color.mError
          pointSize: Style.fontSizeS
          wrapMode: Text.WordWrap
        }
      }
    }

    // Input area
    Rectangle {
      Layout.fillWidth: true
      Layout.preferredHeight: inputLayout.implicitHeight + Style.marginS * 2
      color: Color.mSurface
      radius: Style.radiusM

      RowLayout {
        id: inputLayout
        anchors.fill: parent
        anchors.margins: Style.marginS
        spacing: Style.marginS

        ScrollView {
          Layout.fillWidth: true
          Layout.maximumHeight: 100

          TextArea {
            id: inputField
            text: initialInputText
            placeholderText: "Type a message..."
            placeholderTextColor: Color.mOnSurfaceVariant
            color: Color.mOnSurface
            font.pointSize: Style.fontSizeM
            wrapMode: TextArea.Wrap
            background: null
            selectByMouse: true
            enabled: !isGenerating

            onCursorPositionChanged: {
              if (mainInstance) {
                if (mainInstance.chatInputCursorPosition !== cursorPosition) {
                  mainInstance.chatInputCursorPosition = cursorPosition;
                  mainInstance.saveState();
                }
              }
            }

            onTextChanged: {
              if (mainInstance) {
                if (mainInstance.chatInputText !== text) {
                  mainInstance.chatInputText = text;
                  mainInstance.saveState();
                }
              }
            }

            Keys.onReturnPressed: function (event) {
              if (event.modifiers & Qt.ShiftModifier) {
                inputField.insert(inputField.cursorPosition, "\n");
              } else {
                sendMessage();
              }
              event.accepted = true;
            }

            Keys.onPressed: function (event) {
              if (event.key === Qt.Key_Backtab || (event.key === Qt.Key_Tab && (event.modifiers & Qt.ShiftModifier))) {
                root.requestTabCycleBackward();
                event.accepted = true;
              } else if (event.key === Qt.Key_Tab && !event.modifiers) {
                root.requestTabCycleForward();
                event.accepted = true;
              }
            }
          }
        }

        NIconButton {
          id: sendButton
          icon: isGenerating ? "player-stop" : "send"
          colorFg: isGenerating ? Color.mError : (inputField.text.trim() !== "" ? Color.mPrimary : Color.mOnSurfaceVariant)
          enabled: isGenerating || inputField.text.trim() !== ""
          tooltipText: isGenerating ? "Stop" : "Send"
          onClicked: {
            if (isGenerating) {
              if (mainInstance)
                mainInstance.stopGeneration();
            } else {
              sendMessage();
            }
          }
        }
      }
    }
  }

  function sendMessage() {
    var text = inputField.text.trim();
    if (text === "" || !mainInstance)
      return;
    mainInstance.sendMessage(text);
    inputField.text = "";
    if (mainInstance) {
      mainInstance.chatInputText = "";
      mainInstance.chatInputCursorPosition = 0;
      mainInstance.saveState();
    }
    inputField.forceActiveFocus();
  }

  function focusInput() {
    if (typeof inputField !== 'undefined' && inputField && inputField.forceActiveFocus) {
      inputField.forceActiveFocus();
      if (initialCursorPosition > 0 && initialCursorPosition <= inputField.text.length) {
        inputField.cursorPosition = initialCursorPosition;
      }
    }
  }

  // MessageBubble component (inline for self-contained view)
  component MessageBubble: Item {
    id: root
    property var message: null
    property bool isAssistant: message?.role === "assistant"
    property var blocks: {
      if (isAssistant && MarkdownRenderer.hasMarkdown(message?.content || "")) {
        return MarkdownRenderer.parseBlocks(message?.content || "");
      }
      return [
            {
              type: "paragraph",
              content: message?.content || ""
            }
          ];
    }
    height: bubble.height + timestamp.height + Style.marginXS
    width: parent ? parent.width : 400

    function copyToClipboard(text) {
      if (!text || typeof text !== 'string')
        return;
      try {
        Qt.application.clipboard.text = text;
      } catch (e) {
        console.log("Failed to copy to clipboard:", e);
      }
    }

    // Message bubble
    Rectangle {
      id: bubble
      width: root.width * 0.8
      height: blockColumn.implicitHeight + Style.marginM * 2
      color: isAssistant ? Color.mSurface : Color.mPrimary
      border.color: isAssistant ? Color.mOutline : Color.mPrimary
      border.width: 1
      radius: Style.radiusM
      anchors.right: !isAssistant ? parent.right : undefined
      anchors.left: isAssistant ? parent.left : undefined

      Column {
        id: blockColumn
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: Style.marginM
        spacing: 0

        Repeater {
          model: root.blocks

          delegate: Item {
            id: blockDelegate
            property int tableColCount: (modelData.type === "table" && modelData.headers) ? modelData.headers.length : 1
            width: blockColumn.width
            height: blockContent.height

            Column {
              id: blockContent
              width: parent.width
              spacing: 0

              // === Paragraph ===
              Text {
                visible: modelData.type === "paragraph"
                width: blockColumn.width
                text: root.isAssistant ? MarkdownRenderer.parseInline(modelData.content || "") : (modelData.content || "")
                color: isAssistant ? Color.mOnSurface : Color.mOnPrimary
                font.pointSize: Style.fontSizeS
                wrapMode: Text.WordWrap
                lineHeight: 1.4
                textFormat: root.isAssistant ? Text.StyledText : Text.PlainText

                onLinkActivated: function (link) {
                  if (link && (link.startsWith('http://') || link.startsWith('https://') || link.startsWith('mailto:'))) {
                    try {
                      Qt.openUrlExternally(link);
                    } catch (e) {}
                  }
                }
              }

              // === Header ===
              Text {
                visible: modelData.type === "header"
                width: blockColumn.width
                text: MarkdownRenderer.parseInline(modelData.content || "")
                color: isAssistant ? Color.mOnSurface : Color.mOnPrimary
                font.pointSize: modelData.level <= 1 ? Style.fontSizeXL : modelData.level <= 2 ? Style.fontSizeL : modelData.level <= 3 ? Style.fontSizeM : Style.fontSizeS
                font.weight: Font.Bold
                wrapMode: Text.WordWrap
                lineHeight: 1.3
                textFormat: Text.StyledText
                topPadding: modelData.level <= 2 ? Style.marginS : 0
                bottomPadding: Style.marginXS

                onLinkActivated: function (link) {
                  if (link && (link.startsWith('http://') || link.startsWith('https://') || link.startsWith('mailto:'))) {
                    try {
                      Qt.openUrlExternally(link);
                    } catch (e) {}
                  }
                }
              }

              // === Code Block ===
              Rectangle {
                visible: modelData.type === "code"
                width: blockColumn.width
                height: codeInnerCol.height + Style.marginS * 2
                color: Qt.alpha(Color.mOutline, 0.15)
                border.color: Color.mOutline
                border.width: 1
                radius: Style.radiusS

                Column {
                  id: codeInnerCol
                  anchors.left: parent.left
                  anchors.right: parent.right
                  anchors.margins: Style.marginS
                  anchors.top: parent.top
                  spacing: 0

                  // Language label + copy button row
                  RowLayout {
                    width: parent.width
                    height: visible ? implicitHeight : 0
                    visible: !!modelData.lang && modelData.lang !== ""
                    spacing: Style.marginS

                    NText {
                      text: modelData.lang || ""
                      color: Color.mOnSurfaceVariant
                      pointSize: Style.fontSizeXS
                      font.weight: Font.Medium
                      font.family: "monospace"
                    }

                    Item {
                      Layout.fillWidth: true
                    }

                    Rectangle {
                      Layout.preferredWidth: 22
                      Layout.preferredHeight: 22
                      radius: 4
                      color: codeBtnMouse.containsMouse ? Qt.alpha(Color.mPrimary, 0.15) : "transparent"

                      NIcon {
                        anchors.centerIn: parent
                        icon: "copy"
                        color: Color.mOnSurfaceVariant
                        pointSize: Style.fontSizeXS
                        applyUiScale: false
                      }

                      MouseArea {
                        id: codeBtnMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                          copyToClipboard(modelData.content || "");
                        }
                      }
                    }
                  }

                  Text {
                    width: parent.width
                    text: modelData.content || ""
                    color: Color.mOnSurface
                    font.family: "monospace"
                    font.pointSize: Style.fontSizeS
                    wrapMode: Text.Wrap
                    textFormat: Text.PlainText
                    lineHeight: 1.3
                  }
                }
              }

              // === Bullet List ===
              Column {
                visible: modelData.type === "bullet-list"
                width: blockColumn.width
                spacing: Style.marginXS

                Repeater {
                  model: modelData.type === "bullet-list" ? (modelData.items || []) : []
                  delegate: Text {
                    text: "•  " + MarkdownRenderer.parseInline(modelData)
                    color: isAssistant ? Color.mOnSurface : Color.mOnPrimary
                    font.pointSize: Style.fontSizeS
                    wrapMode: Text.WordWrap
                    textFormat: Text.StyledText
                    width: blockColumn.width
                    lineHeight: 1.4

                    onLinkActivated: function (link) {
                      if (link && (link.startsWith('http://') || link.startsWith('https://') || link.startsWith('mailto:'))) {
                        try {
                          Qt.openUrlExternally(link);
                        } catch (e) {}
                      }
                    }
                  }
                }
              }

              // === Numbered List ===
              Column {
                visible: modelData.type === "numbered-list"
                width: blockColumn.width
                spacing: Style.marginXS

                Repeater {
                  model: modelData.type === "numbered-list" ? (modelData.items || []) : []
                  delegate: Text {
                    text: (modelData.number || (index + 1)) + ".  " + MarkdownRenderer.parseInline(modelData.text || "")
                    color: isAssistant ? Color.mOnSurface : Color.mOnPrimary
                    font.pointSize: Style.fontSizeS
                    wrapMode: Text.WordWrap
                    textFormat: Text.StyledText
                    width: blockColumn.width
                    lineHeight: 1.4

                    onLinkActivated: function (link) {
                      if (link && (link.startsWith('http://') || link.startsWith('https://') || link.startsWith('mailto:'))) {
                        try {
                          Qt.openUrlExternally(link);
                        } catch (e) {}
                      }
                    }
                  }
                }
              }

              // === Task List ===
              Column {
                visible: modelData.type === "task-list"
                width: blockColumn.width
                spacing: Style.marginXS

                Repeater {
                  model: modelData.type === "task-list" ? (modelData.items || []) : []
                  delegate: Text {
                    text: (modelData.checked ? "☑  " : "☐  ") + MarkdownRenderer.parseInline(modelData.text || "")
                    color: isAssistant ? Color.mOnSurface : Color.mOnPrimary
                    font.pointSize: Style.fontSizeS
                    wrapMode: Text.WordWrap
                    textFormat: Text.StyledText
                    width: blockColumn.width
                    lineHeight: 1.4

                    onLinkActivated: function (link) {
                      if (link && (link.startsWith('http://') || link.startsWith('https://') || link.startsWith('mailto:'))) {
                        try {
                          Qt.openUrlExternally(link);
                        } catch (e) {}
                      }
                    }
                  }
                }
              }

              // === Blockquote ===
              Rectangle {
                visible: modelData.type === "blockquote"
                width: blockColumn.width
                height: bqText.implicitHeight + Style.marginS * 2
                color: "transparent"

                Rectangle {
                  anchors.left: parent.left
                  anchors.top: parent.top
                  anchors.bottom: parent.bottom
                  width: 3
                  color: Color.mPrimary
                  radius: 2
                }

                Text {
                  id: bqText
                  anchors.left: parent.left
                  anchors.leftMargin: Style.marginM
                  anchors.right: parent.right
                  anchors.top: parent.top
                  anchors.topMargin: Style.marginS
                  text: MarkdownRenderer.parseInline(modelData.content || "")
                  color: Color.mOnSurfaceVariant
                  font.pointSize: Style.fontSizeS
                  font.italic: true
                  wrapMode: Text.WordWrap
                  textFormat: Text.StyledText
                  lineHeight: 1.4

                  onLinkActivated: function (link) {
                    if (link && (link.startsWith('http://') || link.startsWith('https://') || link.startsWith('mailto:'))) {
                      try {
                        Qt.openUrlExternally(link);
                      } catch (e) {}
                    }
                  }
                }
              }

              // === Table ===
              Rectangle {
                visible: modelData.type === "table"
                width: blockColumn.width
                height: tblCol.implicitHeight + Style.marginS * 2
                color: "transparent"
                border.color: Color.mOutline
                border.width: 1
                radius: Style.radiusS

                Column {
                  id: tblCol
                  anchors.fill: parent
                  anchors.margins: Style.marginS
                  spacing: 0

                  // Header
                  Rectangle {
                    width: parent.width
                    height: tblHeaderRow.implicitHeight + Style.marginXS * 2
                    color: Qt.alpha(Color.mOutline, 0.15)

                    Row {
                      id: tblHeaderRow
                      anchors.fill: parent
                      anchors.margins: Style.marginXS

                      Repeater {
                        model: modelData.type === "table" ? (modelData.headers || []) : []
                        delegate: Item {
                          width: tblCol.width / blockDelegate.tableColCount
                          height: hCell.implicitHeight

                          Text {
                            id: hCell
                            anchors.fill: parent
                            anchors.margins: 2
                            text: MarkdownRenderer.parseInline(modelData || "")
                            color: Color.mOnSurface
                            font.pointSize: Style.fontSizeS
                            font.weight: Font.Bold
                            wrapMode: Text.WordWrap
                            textFormat: Text.StyledText
                          }
                        }
                      }
                    }
                  }

                  Rectangle {
                    width: parent.width
                    height: 1
                    color: Color.mOutline
                  }

                  // Data rows
                  Repeater {
                    model: modelData.type === "table" ? (modelData.rows || []) : []
                    delegate: Rectangle {
                      width: tblCol.width
                      height: tblDataRow.implicitHeight + Style.marginXS * 2
                      color: index % 2 === 0 ? "transparent" : Qt.alpha(Color.mOutline, 0.05)

                      Row {
                        id: tblDataRow
                        anchors.fill: parent
                        anchors.margins: Style.marginXS

                        Repeater {
                          model: modelData || []
                          delegate: Item {
                            width: tblCol.width / blockDelegate.tableColCount
                            height: dCell.implicitHeight

                            Text {
                              id: dCell
                              anchors.fill: parent
                              anchors.margins: 2
                              text: MarkdownRenderer.parseInline(modelData || "")
                              color: Color.mOnSurface
                              font.pointSize: Style.fontSizeS
                              wrapMode: Text.WordWrap
                              textFormat: Text.StyledText
                            }
                          }
                        }
                      }
                    }
                  }
                }
              }

              // === Horizontal Rule ===
              Rectangle {
                visible: modelData.type === "hr"
                width: blockColumn.width
                height: 1
                color: Color.mOutline
                opacity: 0.5
              }
            }
          }
        }
      }
    }

    // Copy button
    Rectangle {
      id: copyButton
      width: 24
      height: 24
      radius: 4
      color: copyMouseArea.containsMouse ? Qt.alpha(Color.mPrimary, 0.1) : "transparent"
      anchors.right: !isAssistant ? bubble.left : undefined
      anchors.left: isAssistant ? bubble.right : undefined
      anchors.verticalCenter: bubble.verticalCenter
      anchors.rightMargin: !isAssistant ? Style.marginS : 0
      anchors.leftMargin: isAssistant ? Style.marginS : 0
      visible: copyMouseArea.containsMouse || rootMouseArea.containsMouse

      NIcon {
        anchors.centerIn: parent
        icon: "copy"
        color: Color.mOnSurfaceVariant
        pointSize: Style.fontSizeXS
        applyUiScale: false
      }

      MouseArea {
        id: copyMouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor

        onClicked: {
          if (message?.content) {
            copyToClipboard(message.content);
            copyFeedback.opacity = 1;
            copyFeedbackTimer.start();
          }
        }
      }
    }

    // Copy feedback
    Rectangle {
      id: copyFeedback
      anchors.right: !isAssistant ? parent.right : undefined
      anchors.left: isAssistant ? parent.left : undefined
      anchors.top: bubble.bottom
      anchors.topMargin: Style.marginXS
      width: feedbackText.implicitWidth + Style.marginS
      height: feedbackText.implicitHeight + Style.marginXS
      color: Color.mPrimary
      radius: Style.radiusS
      opacity: 0

      NText {
        id: feedbackText
        anchors.centerIn: parent
        text: "Copied!"
        color: Color.mOnPrimary
        pointSize: Style.fontSizeXS
      }

      Timer {
        id: copyFeedbackTimer
        interval: 1500
        onTriggered: copyFeedback.opacity = 0
      }

      Behavior on opacity {
        NumberAnimation {
          duration: 200
          easing.type: Easing.InOutQuad
        }
      }
    }

    MouseArea {
      id: rootMouseArea
      anchors.fill: bubble
      hoverEnabled: true
      acceptedButtons: Qt.RightButton

      onPressed: function (mouse) {
        if (mouse.button === Qt.RightButton) {
          if (message?.content) {
            copyToClipboard(message.content);
            copyFeedback.opacity = 1;
            copyFeedbackTimer.start();
          }
          mouse.accepted = true;
        }
      }
    }

    // Timestamp
    NText {
      id: timestamp
      anchors.right: !isAssistant ? parent.right : undefined
      anchors.left: isAssistant ? parent.left : undefined
      anchors.top: bubble.bottom
      anchors.topMargin: Style.marginXS
      text: {
        if (message?.timestamp) {
          try {
            return new Date(message.timestamp).toLocaleTimeString();
          } catch (e) {
            return "";
          }
        }
        return "";
      }
      color: Color.mOnSurfaceVariant
      pointSize: Style.fontSizeXS
      horizontalAlignment: !isAssistant ? Text.AlignRight : Text.AlignLeft
      opacity: 0.8
    }
  }
}
