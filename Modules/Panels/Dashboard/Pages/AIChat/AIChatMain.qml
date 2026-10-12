import QtQuick
import Quickshell
import Quickshell.Io
import "ProviderLogic.js" as ProviderLogic
import qs.Commons
import qs.Services.UI

Item {
  id: root

  property string _responseBuffer: ""

  // AI Chat state
  property var messages: []
  property bool isGenerating: false
  property string currentResponse: ""
  property string errorMessage: ""
  property bool isManuallyStopped: false

  // Active provider
  readonly property string activeProvider: Settings.data.aiChat?.activeProvider || "ollama"

  // Ollama model list
  property var availableOllamaModels: []
  property bool isLoadingOllamaModels: false
  property string ollamaModelLoadError: ""
  property bool isStartingOllama: false
  property bool ollamaModelLoadAutoStartAttempted: false
  property int ollamaRetryDelayMs: 2000

  // LM Studio model list
  property var availableLmStudioModels: []
  property bool isLoadingLmStudioModels: false
  property string lmStudioModelLoadError: ""

  // Cache directory for state
  readonly property string cacheDir: typeof Settings !== 'undefined' && Settings.cacheDir ? Settings.cacheDir + "agnoctural-ai-chat/" : ""
  readonly property string stateCachePath: cacheDir + "state.json"

  property string activeTab: "ai"
  property string chatInputText: ""
  property int chatInputCursorPosition: 0

  // Internet Search state
  property bool isSearchingWeb: false
  property bool isRephrasing: false
  property string pendingSearchQuery: ""

  // Ollama Settings
  readonly property string ollamaBaseUrl: Settings.data.aiChat?.ollama?.baseUrl || "http://localhost:11434"
  readonly property string ollamaModel: Settings.data.aiChat?.ollama?.model || ""
  readonly property real ollamaTemperature: Settings.data.aiChat?.ollama?.temperature || 0.7
  readonly property string ollamaSystemPrompt: Settings.data.aiChat?.ollama?.systemPrompt || "You are a helpful assistant integrated into a Linux desktop shell. Be concise and helpful."

  // LM Studio Settings
  readonly property string lmStudioBaseUrl: Settings.data.aiChat?.lmstudio?.baseUrl || "http://localhost:1234/v1/chat/completions"
  readonly property string lmStudioModel: Settings.data.aiChat?.lmstudio?.model || ""
  readonly property real lmStudioTemperature: Settings.data.aiChat?.lmstudio?.temperature || 0.7
  readonly property string lmStudioSystemPrompt: Settings.data.aiChat?.lmstudio?.systemPrompt || "You are a helpful assistant integrated into a Linux desktop shell. Be concise and helpful."

  // Internet Search Settings
  readonly property bool internetSearchEnabled: Settings.data.aiChat?.internetSearch?.enabled || false
  readonly property string internetSearchProvider: Settings.data.aiChat?.internetSearch?.provider || "duckduckgo"
  readonly property int internetSearchMaxResults: Settings.data.aiChat?.internetSearch?.maxResults || 5
  readonly property string internetSearchSearxngUrl: Settings.data.aiChat?.internetSearch?.searxngUrl || ""
  readonly property bool internetSearchSearxngJsonMode: Settings.data.aiChat?.internetSearch?.searxngJsonMode !== false
  readonly property bool internetSearchFollowUpRephrase: Settings.data.aiChat?.internetSearch?.followUpRephrase || false

  // Computed properties for active provider
  readonly property var availableModels: activeProvider === "ollama" ? availableOllamaModels : availableLmStudioModels
  readonly property string model: activeProvider === "ollama" ? ollamaModel : lmStudioModel
  readonly property bool isLoadingModels: activeProvider === "ollama" ? isLoadingOllamaModels : isLoadingLmStudioModels
  readonly property string modelLoadError: activeProvider === "ollama" ? ollamaModelLoadError : lmStudioModelLoadError

  Component.onCompleted: {
    Logger.i("AIChat", "AI Chat main instance initialized");
    ensureCacheDir();
    loadAllModels();
  }

  Component.onDestruction: {
    cleanupProcesses();
  }

  function cleanupProcesses() {
    if (ollamaModelListProcess.running)
      ollamaModelListProcess.running = false;
    if (lmStudioModelListProcess.running)
      lmStudioModelListProcess.running = false;
    if (ollamaProcess.running)
      ollamaProcess.running = false;
    if (lmStudioProcess.running)
      lmStudioProcess.running = false;
    if (rephraseProcess.running)
      rephraseProcess.running = false;
    if (webSearchProcess.running)
      webSearchProcess.running = false;
  }

  // Function to change model from UI
  function changeModel(newModel) {
    if (!Settings.data.aiChat)
      Settings.data.aiChat = {};

    if (activeProvider === "ollama") {
      if (!Settings.data.aiChat.ollama)
        Settings.data.aiChat.ollama = {};
      Settings.data.aiChat.ollama.model = newModel;
    } else {
      if (!Settings.data.aiChat.lmstudio)
        Settings.data.aiChat.lmstudio = {};
      Settings.data.aiChat.lmstudio.model = newModel;
    }
    Settings.saveImmediate();

    Logger.i("AIChat", "Model changed to: " + newModel);
  }

  // Ensure cache directory exists
  function ensureCacheDir() {
    if (cacheDir) {
      Quickshell.execDetached(["mkdir", "-p", cacheDir]);
    }
  }

  // FileView for state cache
  FileView {
    id: stateCacheFile
    path: root.stateCachePath
    watchChanges: false

    onLoaded: loadStateFromCache()
    onLoadFailed: function (error) {
      if (error === 2)
        Logger.d("AIChat", "No cache file found, starting fresh");
      else
        Logger.e("AIChat", "Failed to load state cache: " + error);
    }
  }

  // Load state from cache file
  function loadStateFromCache() {
    var content = stateCacheFile.text();
    var result = ProviderLogic.processLoadedState(content);

    if (!result) {
      Logger.d("AIChat", "Empty cache file, starting fresh");
      return;
    }

    if (result.error) {
      Logger.e("AIChat", "Failed to parse state cache: " + result.error);
      return;
    }

    root.messages = result.messages;
    root.activeTab = result.activeTab;
    root.chatInputText = result.chatInputText;
    root.chatInputCursorPosition = result.chatInputCursorPosition;
    Logger.d("AIChat", "Loaded " + root.messages.length + " messages from cache");
  }

  // Debounced save timer
  Timer {
    id: saveStateTimer
    interval: 500
    onTriggered: performSaveState()
  }

  property bool saveStateQueued: false

  function saveState() {
    saveStateQueued = true;
    saveStateTimer.restart();
  }

  function performSaveState() {
    if (!saveStateQueued || !cacheDir)
      return;
    saveStateQueued = false;

    try {
      ensureCacheDir();
      var maxHistory = Settings.data.aiChat?.maxHistoryLength || 100;
      var dataStr = ProviderLogic.prepareStateForSave(root.messages, root.activeTab, maxHistory, root.chatInputText, root.chatInputCursorPosition);
      stateCacheFile.setText(dataStr);
    } catch (e) {
      Logger.e("AIChat", "Failed to save state cache: " + e);
    }
  }

  // Add a message to the chat
  function addMessage(role, content) {
    var newMessage = {
      "id": Date.now().toString(),
      "role": role,
      "content": content,
      "timestamp": new Date().toISOString()
    };
    root.messages = [...root.messages, newMessage];
    saveState();
    return newMessage;
  }

  // Clear chat history
  function clearMessages() {
    root.messages = [];
    saveState();
    Logger.i("AIChat", "Chat history cleared");
  }

  // Load models from both providers
  function loadAllModels() {
    loadOllamaModels();
    loadLmStudioModels();
  }

  // =====================
  // Ollama Model Loading
  // =====================
  function loadOllamaModels() {
    ollamaModelLoadAutoStartAttempted = false;
    runOllamaModelLoad();
  }

  function runOllamaModelLoad() {
    if (root.isLoadingOllamaModels || ollamaModelListProcess.running)
      return;
    root.isLoadingOllamaModels = true;
    root.ollamaModelLoadError = "";

    var commandData = ProviderLogic.buildOllamaListCommand(ollamaBaseUrl);
    ollamaModelListProcess.command = commandData.args;
    ollamaModelListProcess.running = true;
  }

  function shouldAutoStartOllamaFromStderr(stderrText) {
    if (!stderrText || stderrText.trim() === "")
      return false;
    return stderrText.includes("Connection refused") || stderrText.includes("Failed to connect") || stderrText.includes("timed out") || stderrText.includes("timeout");
  }

  function shouldAutoStartOllamaFromExitCode(exitCode) {
    return exitCode === 7 || exitCode === 28;
  }

  function scheduleOllamaAutoStartRetry(reason) {
    if (root.ollamaModelLoadAutoStartAttempted)
      return;
    root.ollamaModelLoadAutoStartAttempted = true;
    var started = startOllamaServer(reason);
    if (started)
      ollamaRetryTimer.restart();
  }

  function startOllamaServer(triggerReason) {
    if (root.isStartingOllama)
      return false;
    root.isStartingOllama = true;
    var reasonText = triggerReason ? " (" + triggerReason + ")" : "";
    Logger.i("AIChat", "Starting Ollama server" + reasonText);
    ToastService.showNotice("Starting Ollama server...");

    try {
      Quickshell.execDetached(["ollama", "serve"]);
      ollamaStartCooldownTimer.restart();
      return true;
    } catch (e) {
      root.isStartingOllama = false;
      Logger.e("AIChat", "Failed to start Ollama server: " + e);
      root.ollamaModelLoadError = "Failed to start Ollama automatically. Please run 'ollama serve' manually.";
      ToastService.showError(root.ollamaModelLoadError);
      return false;
    }
  }

  Timer {
    id: ollamaRetryTimer
    interval: root.ollamaRetryDelayMs
    repeat: false
    onTriggered: root.runOllamaModelLoad()
  }

  Timer {
    id: ollamaStartCooldownTimer
    interval: 4000
    repeat: false
    onTriggered: root.isStartingOllama = false
  }

  Process {
    id: ollamaModelListProcess

    stdout: StdioCollector {
      onStreamFinished: {
        root.isLoadingOllamaModels = false;
        Logger.i("AIChat", "Ollama: Raw response received, length: " + (text ? text.length : 0));

        if (!text || text.trim() === "") {
          root.ollamaModelLoadError = "No response from Ollama server. Please ensure Ollama is running with 'ollama serve'";
          root.scheduleOllamaAutoStartRetry("empty_response");
          return;
        }

        var result = ProviderLogic.parseOllamaModelList(text);
        if (result.error) {
          root.ollamaModelLoadError = result.error;
          Logger.e("AIChat", "Ollama: Failed to load models: " + result.error);
        } else {
          root.availableOllamaModels = result.map(function (model) {
            return model.name;
          });
          root.ollamaModelLoadError = "";
          Logger.i("AIChat", "Ollama: Loaded " + root.availableOllamaModels.length + " models");
        }
      }
    }

    stderr: StdioCollector {
      onStreamFinished: {
        root.isLoadingOllamaModels = false;
        if (text && text.trim() !== "") {
          var stderrText = text.trim();
          if (stderrText.includes("Connection refused")) {
            root.ollamaModelLoadError = "Connection refused: Ollama server is not running. Please start Ollama with 'ollama serve'";
          } else if (stderrText.includes("Failed to connect")) {
            root.ollamaModelLoadError = "Connection failed: Unable to reach Ollama server at " + ollamaBaseUrl;
          } else if (stderrText.includes("timeout")) {
            root.ollamaModelLoadError = "Connection timeout: Ollama server not responding.";
          } else {
            root.ollamaModelLoadError = "Connection error: " + stderrText;
          }
          if (root.shouldAutoStartOllamaFromStderr(stderrText)) {
            root.scheduleOllamaAutoStartRetry("model_list_connection_error");
          }
          Logger.e("AIChat", "Ollama model list stderr: " + text);
        }
      }
    }

    onExited: function (exitCode, exitStatus) {
      if (exitCode !== 0) {
        root.isLoadingOllamaModels = false;
        if (exitCode === 22) {
          root.ollamaModelLoadError = "HTTP error 404: Invalid Ollama API endpoint.";
        } else if (exitCode === 7) {
          root.ollamaModelLoadError = "Connection failed: Unable to connect to Ollama server.";
        } else if (exitCode === 28) {
          root.ollamaModelLoadError = "Connection timeout: Ollama server not responding.";
        } else {
          root.ollamaModelLoadError = "Ollama server not running (exit code: " + exitCode + ").";
        }
        if (root.shouldAutoStartOllamaFromExitCode(exitCode)) {
          root.scheduleOllamaAutoStartRetry("model_list_exit_" + exitCode);
        }
      }
    }
  }

  // =====================
  // LM Studio Model Loading
  // =====================
  function loadLmStudioModels() {
    runLmStudioModelLoad();
  }

  function runLmStudioModelLoad() {
    if (root.isLoadingLmStudioModels || lmStudioModelListProcess.running)
      return;
    root.isLoadingLmStudioModels = true;
    root.lmStudioModelLoadError = "";

    var commandData = ProviderLogic.buildLmStudioListCommand(lmStudioBaseUrl);
    lmStudioModelListProcess.command = commandData.args;
    lmStudioModelListProcess.running = true;
  }

  Process {
    id: lmStudioModelListProcess

    stdout: StdioCollector {
      onStreamFinished: {
        root.isLoadingLmStudioModels = false;
        Logger.i("AIChat", "LM Studio: Raw response received, length: " + (text ? text.length : 0));

        if (!text || text.trim() === "") {
          root.lmStudioModelLoadError = "No response from LM Studio server. Ensure local server is running.";
          Logger.e("AIChat", "LM Studio: Empty response");
          return;
        }

        var result = ProviderLogic.parseLmStudioModelList(text);
        if (result.error) {
          root.lmStudioModelLoadError = result.error;
          Logger.e("AIChat", "LM Studio: Failed to load models: " + result.error);
        } else {
          root.availableLmStudioModels = result.map(function (model) {
            return model.name;
          });
          root.lmStudioModelLoadError = "";
          Logger.i("AIChat", "LM Studio: Loaded " + root.availableLmStudioModels.length + " models");
        }
      }
    }

    stderr: StdioCollector {
      onStreamFinished: {
        root.isLoadingLmStudioModels = false;
        if (text && text.trim() !== "") {
          var stderrText = text.trim();
          if (stderrText.includes("Connection refused")) {
            root.lmStudioModelLoadError = "Connection refused: LM Studio server is not running.";
          } else if (stderrText.includes("Failed to connect")) {
            root.lmStudioModelLoadError = "Connection failed: Unable to reach LM Studio server.";
          } else if (stderrText.includes("timeout")) {
            root.lmStudioModelLoadError = "Connection timeout: LM Studio server not responding.";
          } else {
            root.lmStudioModelLoadError = "Connection error: " + stderrText;
          }
          Logger.e("AIChat", "LM Studio model list stderr: " + text);
        }
      }
    }

    onExited: function (exitCode, exitStatus) {
      if (exitCode !== 0) {
        root.isLoadingLmStudioModels = false;
        if (exitCode === 22) {
          root.lmStudioModelLoadError = "HTTP error 404: Invalid LM Studio API endpoint.";
        } else if (exitCode === 7) {
          root.lmStudioModelLoadError = "Connection failed: Unable to connect to LM Studio server.";
        } else if (exitCode === 28) {
          root.lmStudioModelLoadError = "Connection timeout: LM Studio server not responding.";
        } else {
          root.lmStudioModelLoadError = "LM Studio server not running (exit code: " + exitCode + ").";
        }
      }
    }
  }

  // =====================
  // Chat Functions
  // =====================

  // Send a message to active provider (optionally with web search)
  function sendMessage(userMessage) {
    Logger.i("AIChat", "sendMessage called with: " + userMessage);
    if (!userMessage || userMessage.trim() === "")
      return;
    if (root.isGenerating)
      return;

    var currentModel = activeProvider === "ollama" ? ollamaModel : lmStudioModel;
    if (!currentModel || currentModel.trim() === "") {
      root.errorMessage = "Please select a model in settings";
      ToastService.showError(root.errorMessage);
      return;
    }

    addMessage("user", userMessage.trim());
    root.isGenerating = true;
    root.isManuallyStopped = false;
    root.currentResponse = "";
    root.errorMessage = "";
    root.isRephrasing = false;
    root.isSearchingWeb = false;

    if (root.internetSearchEnabled) {
      var isFollowUp = root.messages.length > 1;
      if (isFollowUp && root.internetSearchFollowUpRephrase) {
        startRephrase(userMessage.trim());
      } else {
        startWebSearch(userMessage.trim());
      }
    } else {
      if (activeProvider === "ollama")
        sendOllamaRequest();
      else
        sendLmStudioRequest();
    }
  }

  // Edit a message and regenerate from there
  function editMessage(id, newContent) {
    if (root.isGenerating)
      return;
    if (!newContent || newContent.trim() === "")
      return;

    var index = -1;
    for (var i = 0; i < root.messages.length; i++) {
      if (root.messages[i].id === id) {
        index = i;
        break;
      }
    }
    if (index === -1)
      return;

    root.messages = root.messages.slice(0, index);
    sendMessage(newContent);
  }

  // Regenerate the last assistant response
  function regenerateLastResponse() {
    if (root.isGenerating)
      return;
    if (root.messages.length < 2)
      return;

    var lastIndex = -1;
    for (var i = root.messages.length - 1; i >= 0; i--) {
      if (root.messages[i].role === "assistant") {
        lastIndex = i;
        break;
      }
    }

    if (lastIndex >= 0) {
      root.messages = root.messages.slice(0, lastIndex);
      saveState();
      root.isGenerating = true;
      root.currentResponse = "";
      root.errorMessage = "";

      if (activeProvider === "ollama")
        sendOllamaRequest();
      else
        sendLmStudioRequest();
    }
  }

  // Stop generation (also cancels rephrase and web search)
  function stopGeneration() {
    if (!root.isGenerating)
      return;
    Logger.i("AIChat", "Stopping generation");

    root.isManuallyStopped = true;
    if (rephraseProcess.running)
      rephraseProcess.running = false;
    if (webSearchProcess.running)
      webSearchProcess.running = false;
    if (ollamaProcess.running)
      ollamaProcess.running = false;
    if (lmStudioProcess.running)
      lmStudioProcess.running = false;

    root.isGenerating = false;
    root.isRephrasing = false;
    root.isSearchingWeb = false;
    if (root.currentResponse.trim() !== "") {
      root.addMessage("assistant", root.currentResponse.trim());
    }
    root.currentResponse = "";
  }

  // Build conversation history for API
  function buildConversationHistory() {
    var history = [];
    for (var i = 0; i < root.messages.length; i++) {
      history.push({
                     "role": root.messages[i].role,
                     "content": root.messages[i].content
                   });
    }
    return history;
  }

  // =====================
  // Ollama API Process
  // =====================
  Process {
    id: ollamaProcess
    property string buffer: ""

    stdout: SplitParser {
      onRead: function (data) {
        ollamaProcess.handleStreamData(data);
      }
    }

    stderr: StdioCollector {
      onStreamFinished: {
        if (text && text.trim() !== "") {
          var stderrText = text.trim();
          if (stderrText.includes("Connection refused")) {
            root.errorMessage = "Connection refused: Ollama server is not running.";
          } else if (stderrText.includes("Failed to connect")) {
            root.errorMessage = "Connection failed: Unable to reach Ollama server.";
          } else if (stderrText.includes("timeout")) {
            root.errorMessage = "Connection timeout: Ollama server not responding.";
          } else {
            root.errorMessage = "Ollama error: " + stderrText;
          }
          Logger.e("AIChat", "Ollama stderr: " + text);
        }
      }
    }

    function handleStreamData(data) {
      var result = ProviderLogic.parseOllamaStream(data);
      if (!result)
        return;

      if (result.content) {
        root.currentResponse += result.content;
      } else if (result.error) {
        Logger.e("AIChat", "Ollama stream error: " + result.error);
      } else if (result.raw) {
        ollamaProcess.buffer += result.raw;
        try {
          var errorJson = JSON.parse(ollamaProcess.buffer);
          if (errorJson.error)
            root.errorMessage = errorJson.error.message || "API error";
          ollamaProcess.buffer = "";
        } catch (e) {}
      }
    }

    onExited: function (exitCode, exitStatus) {
      if (root.isManuallyStopped) {
        root.isManuallyStopped = false;
        return;
      }
      root.isGenerating = false;

      if (exitCode !== 0 && root.currentResponse === "") {
        if (root.errorMessage === "")
          root.errorMessage = "Ollama server not running or request failed";
        return;
      }

      if (root.currentResponse.trim() !== "") {
        root.addMessage("assistant", root.currentResponse.trim());
      }
      root.chatInputText = "";
      root.chatInputCursorPosition = 0;
      root.saveState();
      ollamaProcess.buffer = "";
    }
  }

  function sendOllamaRequest(customSystemPrompt) {
    var systemPrompt = customSystemPrompt || ollamaSystemPrompt;
    var history = buildConversationHistory();
    var commandData = ProviderLogic.buildOllamaCommand(ollamaBaseUrl, ollamaModel, systemPrompt, history, ollamaTemperature);
    Logger.i("AIChat", "sendOllamaRequest: endpoint=" + commandData.url);
    ollamaProcess.buffer = "";
    ollamaProcess.command = commandData.args;
    ollamaProcess.running = true;
  }

  // =====================
  // LM Studio API Process
  // =====================
  Process {
    id: lmStudioProcess
    property string buffer: ""

    stdout: SplitParser {
      onRead: function (data) {
        lmStudioProcess.handleStreamData(data);
      }
    }

    stderr: StdioCollector {
      onStreamFinished: {
        if (text && text.trim() !== "") {
          var stderrText = text.trim();
          if (stderrText.includes("Connection refused")) {
            root.errorMessage = "Connection refused: LM Studio server is not running.";
          } else if (stderrText.includes("Failed to connect")) {
            root.errorMessage = "Connection failed: Unable to reach LM Studio server.";
          } else if (stderrText.includes("timeout")) {
            root.errorMessage = "Connection timeout: LM Studio server not responding.";
          } else {
            root.errorMessage = "LM Studio error: " + stderrText;
          }
          Logger.e("AIChat", "LM Studio stderr: " + text);
        }
      }
    }

    function handleStreamData(data) {
      var result = ProviderLogic.parseLmStudioStream(data);
      if (!result)
        return;

      if (result.content) {
        root.currentResponse += result.content;
      } else if (result.error) {
        Logger.e("AIChat", "LM Studio stream error: " + result.error);
      } else if (result.raw) {
        lmStudioProcess.buffer += result.raw;
        try {
          var errorJson = JSON.parse(lmStudioProcess.buffer);
          if (errorJson.error)
            root.errorMessage = errorJson.error.message || "API error";
          lmStudioProcess.buffer = "";
        } catch (e) {}
      }
    }

    onExited: function (exitCode, exitStatus) {
      if (root.isManuallyStopped) {
        root.isManuallyStopped = false;
        return;
      }
      root.isGenerating = false;

      if (exitCode !== 0 && root.currentResponse === "") {
        if (root.errorMessage === "")
          root.errorMessage = "LM Studio server not running or request failed";
        return;
      }

      if (root.currentResponse.trim() !== "") {
        root.addMessage("assistant", root.currentResponse.trim());
      }
      root.chatInputText = "";
      root.chatInputCursorPosition = 0;
      root.saveState();
      lmStudioProcess.buffer = "";
    }
  }

  function sendLmStudioRequest(customSystemPrompt) {
    var systemPrompt = customSystemPrompt || lmStudioSystemPrompt;
    var history = buildConversationHistory();
    var commandData = ProviderLogic.buildLmStudioCommand(lmStudioBaseUrl, lmStudioModel, systemPrompt, history, lmStudioTemperature);
    Logger.i("AIChat", "sendLmStudioRequest: endpoint=" + commandData.url);
    lmStudioProcess.buffer = "";
    lmStudioProcess.command = commandData.args;
    lmStudioProcess.running = true;
  }

  // =====================
  // Web Search: Rephrase follow-up question
  // =====================

  // Rephrase a follow-up question into a standalone search query via non-streaming LLM call
  function startRephrase(userMessage) {
    Logger.i("AIChat", "Rephrasing follow-up question");
    root.isRephrasing = true;
    root.errorMessage = "";

    var history = [];
    for (var i = 0; i < root.messages.length - 1; i++) {
      history.push({
                     "role": root.messages[i].role,
                     "content": root.messages[i].content
                   });
    }

    var baseUrl = activeProvider === "ollama" ? ollamaBaseUrl : lmStudioBaseUrl;
    var model = activeProvider === "ollama" ? ollamaModel : lmStudioModel;
    var commandData = ProviderLogic.buildRephraseCommand(baseUrl, model, history, userMessage);
    Logger.i("AIChat", "Rephrase: endpoint=" + commandData.url);

    rephraseProcess.command = commandData.args;
    rephraseProcess.running = true;
  }

  Process {
    id: rephraseProcess
    property string result: ""

    stdout: StdioCollector {
      onStreamFinished: {
        rephraseProcess.result = ProviderLogic.parseRephraseResult(text || "");
      }
    }

    stderr: StdioCollector {
      onStreamFinished: {
        if (text && text.trim() !== "") {
          Logger.e("AIChat", "Rephrase stderr: " + text);
        }
      }
    }

    onExited: function (exitCode, exitStatus) {
      if (root.isManuallyStopped) {
        root.isManuallyStopped = false;
        return;
      }
      root.isRephrasing = false;

      var query = rephraseProcess.result;
      if (query === "" || exitCode !== 0) {
        Logger.w("AIChat", "Rephrase failed, falling back to original message");
        query = root.messages[root.messages.length - 1].content;
      } else {
        Logger.i("AIChat", "Rephrased query: " + query);
      }
      root.startWebSearch(query);
    }
  }

  // =====================
  // Web Search: Search engine query
  // =====================

  // Execute a web search using the configured provider
  function startWebSearch(query) {
    Logger.i("AIChat", "Web searching for: " + query);
    root.isSearchingWeb = true;
    root.pendingSearchQuery = query;
    root.errorMessage = "";

    var opts = {
      "searxngUrl": root.internetSearchSearxngUrl,
      "searxngJsonMode": root.internetSearchSearxngJsonMode,
      "maxResults": root.internetSearchMaxResults
    };

    var commandData = ProviderLogic.buildSearchCommand(root.internetSearchProvider, query, opts);
    if (!commandData || !commandData.args) {
      Logger.e("AIChat", "Web search: invalid command for provider " + root.internetSearchProvider);
      root.isSearchingWeb = false;
      root.isGenerating = false;
      root.errorMessage = "Search provider configuration is invalid. Please check settings.";
      return;
    }

    webSearchProcess.searchProvider = root.internetSearchProvider;
    webSearchProcess.searchQuery = query;
    webSearchProcess.searchOpts = opts;
    webSearchProcess.command = commandData.args;
    webSearchProcess.running = true;
  }

  Process {
    id: webSearchProcess
    property string searchProvider: "duckduckgo"
    property string searchQuery: ""
    property var searchOpts: ({})
    property string searchResultHtml: ""

    stdout: StdioCollector {
      onStreamFinished: {
        webSearchProcess.searchResultHtml = text || "";
      }
    }

    stderr: StdioCollector {
      onStreamFinished: {
        if (text && text.trim() !== "") {
          Logger.e("AIChat", "Web search stderr: " + text);
        }
      }
    }

    onExited: function (exitCode, exitStatus) {
      if (root.isManuallyStopped) {
        root.isManuallyStopped = false;
        return;
      }
      root.isSearchingWeb = false;

      var html = webSearchProcess.searchResultHtml;
      var opts = webSearchProcess.searchOpts;

      if (exitCode !== 0 || !html || html.trim() === "") {
        Logger.e("AIChat", "Web search failed for: " + webSearchProcess.searchQuery);
        root.isGenerating = false;
        root.errorMessage = "Web search failed. The search engine may be blocking the request. Try again or change the search provider in settings.";
        return;
      }

      var results = ProviderLogic.parseSearchResults(webSearchProcess.searchProvider, html, opts);
      Logger.i("AIChat", "Web search returned " + results.length + " results");

      var systemPrompt = activeProvider === "ollama" ? ollamaSystemPrompt : lmStudioSystemPrompt;
      var enhancedPrompt = ProviderLogic.buildEnhancedSystemPrompt(systemPrompt, results, webSearchProcess.searchQuery);

      // Send to LLM with search-enhanced system prompt
      if (activeProvider === "ollama") {
        sendOllamaRequest(enhancedPrompt);
      } else {
        sendLmStudioRequest(enhancedPrompt);
      }
    }
  }
}
