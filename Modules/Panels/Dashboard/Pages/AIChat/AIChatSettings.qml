/*
* AI Chat settings content, shown inline on the Dashboard.
* Adapted from unified-ai-panel plugin
* Original author: SUDOER1337 (based on j-1in's work)
* Repository: https://github.com/noctalia-dev/noctalia-plugins
* Licensed under MIT License
*/

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Services.UI
import qs.Widgets

ColumnLayout {
  id: root

  // Active provider
  property string editActiveProvider: Settings.data.aiChat?.activeProvider || "ollama"

  // Ollama Settings - local state
  property string editOllamaBaseUrl: Settings.data.aiChat?.ollama?.baseUrl || "http://localhost:11434"
  property string editOllamaModel: Settings.data.aiChat?.ollama?.model || ""
  property real editOllamaTemperature: Settings.data.aiChat?.ollama?.temperature || 0.7
  property string editOllamaSystemPrompt: Settings.data.aiChat?.ollama?.systemPrompt || "You are a helpful assistant integrated into a Linux desktop shell. Be concise and helpful."

  // LM Studio settings - local state
  property string editLmStudioBaseUrl: Settings.data.aiChat?.lmstudio?.baseUrl || "http://localhost:1234/v1/chat/completions"
  property string editLmStudioModel: Settings.data.aiChat?.lmstudio?.model || ""
  property real editLmStudioTemperature: Settings.data.aiChat?.lmstudio?.temperature || 0.7
  property string editLmStudioSystemPrompt: Settings.data.aiChat?.lmstudio?.systemPrompt || "You are a helpful assistant integrated into a Linux desktop shell. Be concise and helpful."

  // General Settings
  property int editMaxHistoryLength: Settings.data.aiChat?.maxHistoryLength || 100

  // Internet Search Settings
  property bool editInternetSearchEnabled: Settings.data.aiChat?.internetSearch?.enabled || false
  property string editInternetSearchProvider: Settings.data.aiChat?.internetSearch?.provider || "duckduckgo"
  property int editInternetSearchMaxResults: Settings.data.aiChat?.internetSearch?.maxResults || 5
  property string editInternetSearchSearxngUrl: Settings.data.aiChat?.internetSearch?.searxngUrl || ""
  property bool editInternetSearchSearxngJsonMode: Settings.data.aiChat?.internetSearch?.searxngJsonMode !== false
  property bool editInternetSearchFollowUpRephrase: Settings.data.aiChat?.internetSearch?.followUpRephrase || false

  spacing: Style.marginM

  // -- Auto-persist --
  // Every edit is written back to Settings after a short debounce, so there is
  // no Save button and a partly-typed value is never lost when leaving.
  Timer {
    id: saveTimer
    interval: 300
    repeat: false
    onTriggered: root.saveSettings()
  }

  function scheduleSave() {
    saveTimer.restart();
  }

  onEditActiveProviderChanged: root.scheduleSave()
  onEditOllamaBaseUrlChanged: root.scheduleSave()
  onEditOllamaModelChanged: root.scheduleSave()
  onEditOllamaTemperatureChanged: root.scheduleSave()
  onEditOllamaSystemPromptChanged: root.scheduleSave()
  onEditLmStudioBaseUrlChanged: root.scheduleSave()
  onEditLmStudioModelChanged: root.scheduleSave()
  onEditLmStudioTemperatureChanged: root.scheduleSave()
  onEditLmStudioSystemPromptChanged: root.scheduleSave()
  onEditMaxHistoryLengthChanged: root.scheduleSave()
  onEditInternetSearchEnabledChanged: root.scheduleSave()
  onEditInternetSearchProviderChanged: root.scheduleSave()
  onEditInternetSearchMaxResultsChanged: root.scheduleSave()
  onEditInternetSearchSearxngUrlChanged: root.scheduleSave()
  onEditInternetSearchSearxngJsonModeChanged: root.scheduleSave()
  onEditInternetSearchFollowUpRephraseChanged: root.scheduleSave()

  Component.onCompleted: {
    Logger.i("AIChatSettings", "Settings UI loaded");
  }

  // ==================
  // Active Provider Section
  // ==================
  NText {
    text: "Active Provider"
    pointSize: Style.fontSizeM
    font.weight: Font.Bold
    color: Color.mOnSurface
  }

  NComboBox {
    Layout.fillWidth: true
    label: "Active Provider"
    description: "Select which AI provider to use for chat"
    model: [
      {
        "key": "ollama",
        "name": "Ollama"
      },
      {
        "key": "lmstudio",
        "name": "LM Studio"
      }
    ]
    currentKey: root.editActiveProvider
    onSelected: function (key) {
      root.editActiveProvider = key;
    }
    defaultValue: "ollama"
  }

  NDivider {
    Layout.fillWidth: true
    Layout.topMargin: Style.marginM
    Layout.bottomMargin: Style.marginM
  }

  // ==================
  // Ollama Settings Section
  // ==================
  NText {
    text: "Ollama Settings"
    pointSize: Style.fontSizeM
    font.weight: Font.Bold
    color: Color.mOnSurface
  }

  NTextInput {
    Layout.fillWidth: true
    label: "Ollama Server URL"
    description: "URL of your local Ollama server"
    text: root.editOllamaBaseUrl
    placeholderText: "http://localhost:11434"
    onTextChanged: root.editOllamaBaseUrl = text
  }

  // Ollama connection test
  RowLayout {
    Layout.fillWidth: true
    spacing: Style.marginS

    NButton {
      text: "Test Ollama Connection"
      onClicked: testOllamaConnection()
    }

    NText {
      id: ollamaConnectionStatus
      text: ""
      color: ollamaConnectionSuccess ? Color.mPrimary : Color.mError
      pointSize: Style.fontSizeS
      Layout.fillWidth: true
      wrapMode: Text.Wrap
      visible: text !== ""
    }
  }

  property bool ollamaConnectionSuccess: false
  property bool isTestingOllamaConnection: false

  function testOllamaConnection() {
    ollamaConnectionStatus.text = "Testing Ollama connection...";
    ollamaConnectionStatus.visible = true;
    isTestingOllamaConnection = true;
    ollamaConnectionSuccess = false;

    var endpoint = root.editOllamaBaseUrl.trim();
    if (!endpoint.endsWith("/api/tags")) {
      endpoint = endpoint.endsWith("/") ? endpoint + "api/tags" : endpoint + "/api/tags";
    }

    ollamaTestProcess.command = ["curl", "-s", "-S", "--connect-timeout", "5", "--max-time", "10", "-f", endpoint];
    ollamaTestProcess.running = true;
  }

  Process {
    id: ollamaTestProcess

    stdout: StdioCollector {
      onStreamFinished: {
        isTestingOllamaConnection = false;
        if (text && text.trim() !== "") {
          try {
            var response = JSON.parse(text);
            if (response.models && Array.isArray(response.models)) {
              ollamaConnectionStatus.text = "Connected! Found " + response.models.length + " models.";
              ollamaConnectionSuccess = true;
            } else {
              ollamaConnectionStatus.text = "Connected but no models found.";
              ollamaConnectionSuccess = true;
            }
          } catch (e) {
            ollamaConnectionStatus.text = "Connected but response format unexpected.";
            ollamaConnectionSuccess = true;
          }
        } else {
          ollamaConnectionStatus.text = "No response from server.";
          ollamaConnectionSuccess = false;
        }
      }
    }

    stderr: StdioCollector {
      onStreamFinished: {
        if (text && text.trim() !== "") {
          var stderrText = text.trim();
          if (stderrText.includes("Connection refused")) {
            ollamaConnectionStatus.text = "Connection refused. Is Ollama running?";
          } else if (stderrText.includes("Failed to connect")) {
            ollamaConnectionStatus.text = "Failed to connect to " + root.editOllamaBaseUrl;
          } else if (stderrText.includes("timeout")) {
            ollamaConnectionStatus.text = "Connection timeout.";
          } else {
            ollamaConnectionStatus.text = "Error: " + stderrText;
          }
          isTestingOllamaConnection = false;
          ollamaConnectionSuccess = false;
        }
      }
    }

    onExited: function (exitCode, exitStatus) {
      if (exitCode !== 0 && ollamaConnectionStatus.text === "") {
        isTestingOllamaConnection = false;
        if (exitCode === 22)
          ollamaConnectionStatus.text = "Invalid URL (404 error).";
        else if (exitCode === 7)
          ollamaConnectionStatus.text = "Failed to connect. Is Ollama running?";
        else if (exitCode === 28)
          ollamaConnectionStatus.text = "Connection timeout.";
        else
          ollamaConnectionStatus.text = "Connection failed (code: " + exitCode + ").";
        ollamaConnectionSuccess = false;
      }
    }
  }

  // Ollama Model selection
  NComboBox {
    id: ollamaModelComboBox
    Layout.fillWidth: true
    label: "Ollama Model"
    description: "Select the Ollama model to use"
    model: {
      // We'll load available models from the main instance if available
      var models = [];
      // The main instance loads models on demand, so we just show a placeholder
      // When the user clicks the combo, it will trigger loading
      return models;
    }
    currentKey: root.editOllamaModel
    onSelected: function (key) {
      root.editOllamaModel = key;
    }
    enabled: false
  }

  RowLayout {
    Layout.fillWidth: true
    spacing: Style.marginS

    NButton {
      text: "Start Ollama"
      onClicked: {
        Quickshell.execDetached(["ollama", "serve"]);
        ToastService.showNotice("Ollama start command sent");
      }
    }

    NButton {
      text: "Refresh Ollama Models"
      onClicked: {
        // This will be handled by the main instance when the panel is opened
        ToastService.showNotice("Open AI Chat panel to refresh models");
      }
    }
  }

  // Ollama Temperature
  ColumnLayout {
    Layout.fillWidth: true
    spacing: Style.marginS

    NLabel {
      label: "Ollama Temperature: " + root.editOllamaTemperature.toFixed(1)
      description: "Controls randomness in Ollama responses"
    }

    NSlider {
      Layout.fillWidth: true
      from: 0
      to: 2
      stepSize: 0.1
      value: root.editOllamaTemperature
      onValueChanged: root.editOllamaTemperature = value
    }
  }

  // Ollama System Prompt
  ColumnLayout {
    Layout.fillWidth: true
    spacing: Style.marginS

    NLabel {
      label: "Ollama System Prompt"
      description: "Instructions for the Ollama AI assistant"
    }

    Rectangle {
      Layout.fillWidth: true
      Layout.preferredHeight: 80
      color: Color.mSurface
      radius: Style.radiusS
      border.color: Color.mOutline
      border.width: 1

      ScrollView {
        anchors.fill: parent
        anchors.margins: Style.marginS

        TextArea {
          text: root.editOllamaSystemPrompt
          placeholderText: "Enter system prompt for Ollama..."
          color: Color.mOnSurface
          font.pointSize: Style.fontSizeS
          wrapMode: TextArea.Wrap
          background: null
          onTextChanged: root.editOllamaSystemPrompt = text
        }
      }
    }
  }

  NDivider {
    Layout.fillWidth: true
    Layout.topMargin: Style.marginM
    Layout.bottomMargin: Style.marginM
  }

  // ==================
  // LM Studio Settings Section
  // ==================
  NText {
    text: "LM Studio Settings"
    pointSize: Style.fontSizeM
    font.weight: Font.Bold
    color: Color.mOnSurface
  }

  NTextInput {
    Layout.fillWidth: true
    label: "LM Studio API URL"
    description: "URL of your local LM Studio OpenAI-compatible endpoint"
    text: root.editLmStudioBaseUrl
    placeholderText: "http://localhost:1234/v1/chat/completions"
    onTextChanged: root.editLmStudioBaseUrl = text
  }

  // LM Studio connection test
  RowLayout {
    Layout.fillWidth: true
    spacing: Style.marginS

    NButton {
      text: "Test LM Studio Connection"
      onClicked: testLmStudioConnection()
    }

    NText {
      id: lmStudioConnectionStatus
      text: ""
      color: lmStudioConnectionSuccess ? Color.mPrimary : Color.mError
      pointSize: Style.fontSizeS
      Layout.fillWidth: true
      wrapMode: Text.Wrap
      visible: text !== ""
    }
  }

  property bool lmStudioConnectionSuccess: false
  property bool isTestingLmStudioConnection: false

  function testLmStudioConnection() {
    lmStudioConnectionStatus.text = "Testing LM Studio connection...";
    lmStudioConnectionStatus.visible = true;
    isTestingLmStudioConnection = true;
    lmStudioConnectionSuccess = false;

    var endpoint = root.editLmStudioBaseUrl.trim();
    if (endpoint.includes("/v1/chat/completions")) {
      endpoint = endpoint.replace("/v1/chat/completions", "/v1/models");
    } else if (!endpoint.includes("/v1/models")) {
      endpoint = endpoint.endsWith("/") ? endpoint + "v1/models" : endpoint + "/v1/models";
    }

    lmStudioTestProcess.command = ["curl", "-s", "-S", "--connect-timeout", "5", "--max-time", "10", "-f", endpoint];
    lmStudioTestProcess.running = true;
  }

  Process {
    id: lmStudioTestProcess

    stdout: StdioCollector {
      onStreamFinished: {
        isTestingLmStudioConnection = false;
        if (text && text.trim() !== "") {
          try {
            var response = JSON.parse(text);
            if (response.data && Array.isArray(response.data)) {
              lmStudioConnectionStatus.text = "Connected. Found " + response.data.length + " models.";
              lmStudioConnectionSuccess = true;
            } else {
              lmStudioConnectionStatus.text = "Connected but no models found.";
              lmStudioConnectionSuccess = true;
            }
          } catch (e) {
            lmStudioConnectionStatus.text = "Connected but response format unexpected.";
            lmStudioConnectionSuccess = true;
          }
        } else {
          lmStudioConnectionStatus.text = "No response from server.";
          lmStudioConnectionSuccess = false;
        }
      }
    }

    stderr: StdioCollector {
      onStreamFinished: {
        if (text && text.trim() !== "") {
          var stderrText = text.trim();
          if (stderrText.includes("Connection refused")) {
            lmStudioConnectionStatus.text = "Connection refused. Is LM Studio server running?";
          } else if (stderrText.includes("Failed to connect")) {
            lmStudioConnectionStatus.text = "Failed to connect to " + root.editLmStudioBaseUrl;
          } else if (stderrText.includes("timeout")) {
            lmStudioConnectionStatus.text = "Connection timeout.";
          } else {
            lmStudioConnectionStatus.text = "Error: " + stderrText;
          }
          isTestingLmStudioConnection = false;
          lmStudioConnectionSuccess = false;
        }
      }
    }

    onExited: function (exitCode, exitStatus) {
      if (exitCode !== 0 && lmStudioConnectionStatus.text === "") {
        isTestingLmStudioConnection = false;
        if (exitCode === 22)
          lmStudioConnectionStatus.text = "Invalid URL (404 error).";
        else if (exitCode === 7)
          lmStudioConnectionStatus.text = "Failed to connect. Is LM Studio running?";
        else if (exitCode === 28)
          lmStudioConnectionStatus.text = "Connection timeout.";
        else
          lmStudioConnectionStatus.text = "Connection failed (code: " + exitCode + ").";
        lmStudioConnectionSuccess = false;
      }
    }
  }

  // LM Studio Model selection
  NComboBox {
    id: lmStudioModelComboBox
    Layout.fillWidth: true
    label: "LM Studio Model"
    description: "Select the LM Studio model to use"
    model: []
    currentKey: root.editLmStudioModel
    onSelected: function (key) {
      root.editLmStudioModel = key;
    }
    enabled: false
  }

  RowLayout {
    Layout.fillWidth: true
    spacing: Style.marginS

    NButton {
      text: "Refresh LM Studio Models"
      onClicked: {
        ToastService.showNotice("Open AI Chat panel to refresh models");
      }
    }
  }

  // LM Studio Temperature
  ColumnLayout {
    Layout.fillWidth: true
    spacing: Style.marginS

    NLabel {
      label: "LM Studio Temperature: " + root.editLmStudioTemperature.toFixed(1)
      description: "Controls randomness in LM Studio responses"
    }

    NSlider {
      Layout.fillWidth: true
      from: 0
      to: 2
      stepSize: 0.1
      value: root.editLmStudioTemperature
      onValueChanged: root.editLmStudioTemperature = value
    }
  }

  // LM Studio System Prompt
  ColumnLayout {
    Layout.fillWidth: true
    spacing: Style.marginS

    NLabel {
      label: "LM Studio System Prompt"
      description: "Instructions for the LM Studio AI assistant"
    }

    Rectangle {
      Layout.fillWidth: true
      Layout.preferredHeight: 80
      color: Color.mSurface
      radius: Style.radiusS
      border.color: Color.mOutline
      border.width: 1

      ScrollView {
        anchors.fill: parent
        anchors.margins: Style.marginS

        TextArea {
          text: root.editLmStudioSystemPrompt
          placeholderText: "Enter system prompt for LM Studio..."
          color: Color.mOnSurface
          font.pointSize: Style.fontSizeS
          wrapMode: TextArea.Wrap
          background: null
          onTextChanged: root.editLmStudioSystemPrompt = text
        }
      }
    }
  }

  NDivider {
    Layout.fillWidth: true
    Layout.topMargin: Style.marginM
    Layout.bottomMargin: Style.marginM
  }

  // ==================
  // Internet Search Settings
  // ==================
  NText {
    text: "Internet Search"
    pointSize: Style.fontSizeM
    font.weight: Font.Bold
    color: Color.mOnSurface
  }

  NToggle {
    Layout.fillWidth: true
    label: "Enable Internet Search"
    description: "When enabled, every message gets web search results injected as context before the LLM responds"
    checked: root.editInternetSearchEnabled
    onToggled: function (checked) {
      root.editInternetSearchEnabled = checked;
    }
    defaultValue: false
  }

  NComboBox {
    Layout.fillWidth: true
    enabled: root.editInternetSearchEnabled
    label: "Search Provider"
    description: "Which search engine to use for web lookups"
    model: [
      {
        "key": "duckduckgo",
        "name": "DuckDuckGo (scrape)"
      },
      {
        "key": "searxng",
        "name": "SearXNG (self-hosted)"
      },
      {
        "key": "startpage",
        "name": "StartPage (scrape)"
      }
    ]
    currentKey: root.editInternetSearchProvider
    onSelected: function (key) {
      root.editInternetSearchProvider = key;
    }
    defaultValue: "duckduckgo"
  }

  NTextInput {
    Layout.fillWidth: true
    visible: root.editInternetSearchProvider === "searxng"
    enabled: root.editInternetSearchEnabled
    label: "SearXNG Instance URL"
    description: "URL of your self-hosted SearXNG instance (e.g. https://searxng.example.com)"
    text: root.editInternetSearchSearxngUrl
    placeholderText: "https://searxng.example.com"
    onTextChanged: root.editInternetSearchSearxngUrl = text
  }

  NToggle {
    Layout.fillWidth: true
    visible: root.editInternetSearchProvider === "searxng"
    enabled: root.editInternetSearchEnabled
    label: "SearXNG JSON Mode"
    description: "Use JSON API for cleaner results (recommended). Disable if you have HTML-only mode."
    checked: root.editInternetSearchSearxngJsonMode
    onToggled: function (checked) {
      root.editInternetSearchSearxngJsonMode = checked;
    }
    defaultValue: true
  }

  ColumnLayout {
    Layout.fillWidth: true
    enabled: root.editInternetSearchEnabled
    spacing: Style.marginS

    NLabel {
      label: "Max Results: " + root.editInternetSearchMaxResults
      description: "Number of search results to include as context (1-10)"
    }

    NSlider {
      Layout.fillWidth: true
      from: 1
      to: 10
      stepSize: 1
      value: root.editInternetSearchMaxResults
      onValueChanged: root.editInternetSearchMaxResults = value
    }
  }

  NToggle {
    Layout.fillWidth: true
    enabled: root.editInternetSearchEnabled
    label: "Rephrase Follow-up Questions"
    description: "For multi-turn conversations, rephrase follow-up questions into standalone search queries via a quick LLM call"
    checked: root.editInternetSearchFollowUpRephrase
    onToggled: function (checked) {
      root.editInternetSearchFollowUpRephrase = checked;
    }
    defaultValue: true
  }

  NDivider {
    Layout.fillWidth: true
    Layout.topMargin: Style.marginM
    Layout.bottomMargin: Style.marginM
  }

  // ==================
  // General Settings
  // ==================
  NText {
    text: "General Settings"
    pointSize: Style.fontSizeM
    font.weight: Font.Bold
    color: Color.mOnSurface
  }

  // Max history length
  ColumnLayout {
    Layout.fillWidth: true
    spacing: Style.marginS

    NLabel {
      label: "Max History Length: " + root.editMaxHistoryLength
      description: "Maximum number of messages to keep in chat history (10-500)"
    }

    NSlider {
      Layout.fillWidth: true
      from: 10
      to: 500
      stepSize: 10
      value: root.editMaxHistoryLength
      onValueChanged: root.editMaxHistoryLength = value
    }
  }

  NDivider {
    Layout.fillWidth: true
    Layout.topMargin: Style.marginM
    Layout.bottomMargin: Style.marginM
  }

  // ==================
  // Save Function
  // ==================
  function saveSettings() {
    // Save active provider
    Settings.data.aiChat.activeProvider = root.editActiveProvider;

    // Save Ollama settings
    Settings.data.aiChat.ollama.baseUrl = root.editOllamaBaseUrl;
    Settings.data.aiChat.ollama.model = root.editOllamaModel;
    Settings.data.aiChat.ollama.temperature = root.editOllamaTemperature;
    Settings.data.aiChat.ollama.systemPrompt = root.editOllamaSystemPrompt;

    // Save LM Studio settings
    Settings.data.aiChat.lmstudio.baseUrl = root.editLmStudioBaseUrl;
    Settings.data.aiChat.lmstudio.model = root.editLmStudioModel;
    Settings.data.aiChat.lmstudio.temperature = root.editLmStudioTemperature;
    Settings.data.aiChat.lmstudio.systemPrompt = root.editLmStudioSystemPrompt;

    // Save general settings
    Settings.data.aiChat.maxHistoryLength = root.editMaxHistoryLength;

    // Save internet search settings
    Settings.data.aiChat.internetSearch.enabled = root.editInternetSearchEnabled;
    Settings.data.aiChat.internetSearch.provider = root.editInternetSearchProvider;
    Settings.data.aiChat.internetSearch.maxResults = root.editInternetSearchMaxResults;
    Settings.data.aiChat.internetSearch.searxngUrl = root.editInternetSearchSearxngUrl;
    Settings.data.aiChat.internetSearch.searxngJsonMode = root.editInternetSearchSearxngJsonMode;
    Settings.data.aiChat.internetSearch.followUpRephrase = root.editInternetSearchFollowUpRephrase;

    Logger.i("AIChatSettings", "Settings saved successfully");
  }
}
