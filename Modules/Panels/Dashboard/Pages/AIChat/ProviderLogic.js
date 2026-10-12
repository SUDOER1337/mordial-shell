.pragma library

// ===================================
// AI Chat Provider Logic
// ===================================
// Adapted from unified-ai-panel plugin
// Original author: SUDOER1337 (based on j-1in's work)
// Repository: https://github.com/noctalia-dev/noctalia-plugins
// Licensed under MIT License

// ===================================
// Ollama Provider Logic
// ===================================

function buildOllamaCommand(baseUrl, model, systemPrompt, history, temperature) {
  var messages = [];

  if (systemPrompt && systemPrompt.trim() !== "") {
    messages.push({
      "role": "system",
      "content": systemPrompt
    });
  }

  for (var i = 0; i < history.length; i++) {
    messages.push(history[i]);
  }

  var payload = {
    "model": model,
    "messages": messages,
    "temperature": temperature,
    "stream": true
  };

  var endpoint = baseUrl.trim();

  if (endpoint.includes("/api/chat") || endpoint.includes("/v1/chat/completions")) {
  } else {
    if (endpoint.endsWith("/")) {
      endpoint = endpoint + "api/chat";
    } else {
      endpoint = endpoint + "/api/chat";
    }
  }

  var args = ["curl", "-s", "-S", "--no-buffer", "-X", "POST", "-H", "Content-Type: application/json"];
  args.push("-d", JSON.stringify(payload));
  args.push(endpoint);

  return {
    "url": endpoint,
    "payload": JSON.stringify(payload),
    "args": args
  };
}

function parseOllamaStream(data) {
  if (!data)
    return null;
  var line = data.trim();
  if (line === "")
    return null;

  try {
    var json = JSON.parse(line);
    if (json.message && json.message.content) {
      if (json.done) {
        return {
          done: true
        };
      }
      return {
        content: json.message.content
      };
    }
    else if (line.startsWith("data: ")) {
      var jsonStr = line.substring(6).trim();
      if (jsonStr === "[DONE]")
        return {
          done: true
        };

      var json = JSON.parse(jsonStr);
      if (json.choices && json.choices[0]) {
        if (json.choices[0].delta && json.choices[0].delta.content) {
          return {
            content: json.choices[0].delta.content
          };
        } else if (json.choices[0].message && json.choices[0].message.content) {
          return {
            content: json.choices[0].message.content
          };
        }
      }
    }
  } catch (e) {
    return {
      raw: line
    };
  }

  return {
    raw: line
  };
}

// ===================================
// Ollama Model Discovery
// ===================================

function buildOllamaListCommand(baseUrl) {
  var endpoint = baseUrl.trim();
  if (!endpoint.endsWith("/api/tags")) {
    if (endpoint.endsWith("/")) {
      endpoint = endpoint + "api/tags";
    } else {
      endpoint = endpoint + "/api/tags";
    }
  }

  return {
    "args": ["curl", "-s", "-S", "--connect-timeout", "3", "--max-time", "10", "-f", endpoint]
  };
}

function parseOllamaModelList(responseText) {
  if (!responseText || typeof responseText !== 'string') {
    return { error: "Invalid response text" };
  }

  try {
    var cleanText = responseText.trim();
    var jsonEnd = cleanText.lastIndexOf("}");
    if (jsonEnd > 0) {
      var modelsEnd = cleanText.lastIndexOf("]}");
      if (modelsEnd > 0 && modelsEnd > jsonEnd - 10) {
        cleanText = cleanText.substring(0, modelsEnd + 2);
      } else {
        cleanText = cleanText.substring(0, jsonEnd + 1);
      }
    }

    if (!cleanText.startsWith('{') || !cleanText.endsWith('}')) {
      return { error: "Invalid JSON format" };
    }

    var response = JSON.parse(cleanText);
    if (!response || typeof response !== 'object') {
      return { error: "Invalid response structure" };
    }

    if (!response.models || !Array.isArray(response.models)) {
      return { error: "No models array in response" };
    }

    return response.models.map(function(model) {
      if (!model || !model.name) {
        return null;
      }
      return {
        name: model.name,
        display: model.name.split(":")[0] || model.name,
        tag: model.name.split(":")[1] || "latest",
        size: model.size || 0,
        modified: model.modified_at || ""
      };
    }).filter(function(model) { return model !== null; });

  } catch (e) {
    return {
      error: "Failed to parse model list: " + (e.toString() || "Unknown error")
    };
  }
}

// ===================================
// LM Studio Provider Logic
// ===================================

function normalizeChatEndpoint(baseUrl) {
  var endpoint = (baseUrl || "").trim();
  if (endpoint === "") {
    return "http://localhost:1234/v1/chat/completions";
  }

  if (endpoint.includes("/v1/chat/completions")) {
    return endpoint;
  }

  if (endpoint.endsWith("/")) {
    return endpoint + "v1/chat/completions";
  }
  return endpoint + "/v1/chat/completions";
}

function normalizeModelsEndpoint(baseUrl) {
  var endpoint = (baseUrl || "").trim();
  if (endpoint === "") {
    return "http://localhost:1234/v1/models";
  }

  if (endpoint.includes("/v1/models")) {
    return endpoint;
  }

  if (endpoint.includes("/v1/chat/completions")) {
    return endpoint.replace("/v1/chat/completions", "/v1/models");
  }

  if (endpoint.endsWith("/")) {
    return endpoint + "v1/models";
  }
  return endpoint + "/v1/models";
}

function buildLmStudioCommand(baseUrl, model, systemPrompt, history, temperature) {
  var messages = [];

  if (systemPrompt && systemPrompt.trim() !== "") {
    messages.push({
      "role": "system",
      "content": systemPrompt
    });
  }

  for (var i = 0; i < history.length; i++) {
    messages.push(history[i]);
  }

  var payload = {
    "model": model,
    "messages": messages,
    "temperature": temperature,
    "stream": true
  };

  var endpoint = normalizeChatEndpoint(baseUrl);
  var args = ["curl", "-s", "-S", "--no-buffer", "-X", "POST", "-H", "Content-Type: application/json"];
  args.push("-d", JSON.stringify(payload));
  args.push(endpoint);

  return {
    "url": endpoint,
    "payload": JSON.stringify(payload),
    "args": args
  };
}

function parseLmStudioStream(data) {
  if (!data)
    return null;
  var line = data.trim();
  if (line === "")
    return null;

  try {
    if (line.startsWith("data: ")) {
      var jsonStr = line.substring(6).trim();
      if (jsonStr === "[DONE]") {
        return { done: true };
      }
      var json = JSON.parse(jsonStr);
      if (json.choices && json.choices[0]) {
        if (json.choices[0].delta && json.choices[0].delta.content) {
          return { content: json.choices[0].delta.content };
        }
        if (json.choices[0].message && json.choices[0].message.content) {
          return { content: json.choices[0].message.content };
        }
      }
    } else {
      var directJson = JSON.parse(line);
      if (directJson.choices && directJson.choices[0]) {
        if (directJson.choices[0].delta && directJson.choices[0].delta.content) {
          return { content: directJson.choices[0].delta.content };
        }
        if (directJson.choices[0].message && directJson.choices[0].message.content) {
          return { content: directJson.choices[0].message.content };
        }
      }
    }
  } catch (e) {
    return { raw: line };
  }

  return { raw: line };
}

// ===================================
// LM Studio Model Discovery
// ===================================

function buildLmStudioListCommand(baseUrl) {
  var endpoint = normalizeModelsEndpoint(baseUrl);
  return {
    "args": ["curl", "-s", "-S", "--connect-timeout", "3", "--max-time", "10", "-f", endpoint]
  };
}

function parseLmStudioModelList(responseText) {
  if (!responseText || typeof responseText !== 'string') {
    return { error: "Invalid response text" };
  }

  try {
    var response = JSON.parse(responseText.trim());
    if (!response || typeof response !== 'object') {
      return { error: "Invalid response structure" };
    }

    if (!response.data || !Array.isArray(response.data)) {
      return { error: "No data array in response" };
    }

    return response.data.map(function(model) {
      if (!model || !model.id) {
        return null;
      }
      return {
        name: model.id,
        display: model.id,
        tag: "default",
        size: model.size || 0,
        modified: model.created || ""
      };
    }).filter(function(model) { return model !== null; });
  } catch (e) {
    return {
      error: "Failed to parse model list: " + (e.toString() || "Unknown error")
    };
  }
}

// ===================================
// Shared State Management
// ===================================

function processLoadedState(content) {
  if (!content || content.trim() === "") {
    return null;
  }
  try {
    var cached = JSON.parse(content);
    return {
      messages: cached.messages || [],
      activeTab: cached.activeTab || "ai",
      chatInputText: cached.chatInputText || "",
      chatInputCursorPosition: cached.chatInputCursorPosition || 0
    };
  } catch (e) {
    return {
      error: e.toString()
    };
  }
}

function prepareStateForSave(messages, activeTab, maxHistory, chatInputText, chatInputCursorPosition) {
  var maxLog = maxHistory || 100;
  var toSave = messages.slice(-maxLog);

  return JSON.stringify({
    messages: toSave,
    activeTab: activeTab,
    chatInputText: chatInputText || "",
    chatInputCursorPosition: chatInputCursorPosition || 0,
    timestamp: Math.floor(Date.now() / 1000)
  }, null, 2);
}

// ===================================
// Web Search: Rephrase Follow-up
// ===================================

function buildRephraseCommand(baseUrl, model, chatHistory, question) {
  var endpoint = baseUrl.trim();
  var isOpenAICompat = endpoint.includes("/v1/chat/completions");

  var chatHistoryText = "";
  for (var i = 0; i < chatHistory.length; i++) {
    var role = chatHistory[i].role === "user" ? "User" : "Assistant";
    chatHistoryText += role + ": " + chatHistory[i].content + "\n";
  }

  var rephrasePrompt =
    "You will rephrase follow-up questions into concise, standalone search queries optimized for internet search engines. " +
    "Transform conversational questions into keyword-focused search terms by removing unnecessary words, question formats, " +
    "and context dependencies while preserving the core information need.\n\n" +
    "ONLY RETURN QUERY WITHOUT ANY TEXT\n\n" +
    "Examples:\n" +
    "Follow-up question: What are the symptoms of a heart attack?\n" +
    "heart attack symptoms\n\n" +
    "Follow-up question: Where is the upcoming Olympics being held?\n" +
    "upcoming Olympics location\n\n" +
    "Follow-up question: How does photosynthesis work in plants?\n" +
    "photosynthesis process plants\n\n" +
    "Follow-up question: What's the current stock price of Apple?\n" +
    "Apple stock price today\n\n" +
    "Previous Conversation:\n" +
    (chatHistoryText.trim() || "(no previous conversation)") +
    "\n\nFollow-up question: " + question;

  var messages = [{ "role": "user", "content": rephrasePrompt }];

  var payload = {
    "model": model,
    "messages": messages,
    "temperature": 0,
    "stream": false
  };

  if (!isOpenAICompat) {
    if (endpoint.endsWith("/")) {
      endpoint = endpoint + "api/chat";
    } else if (!endpoint.includes("/api/chat")) {
      endpoint = endpoint + "/api/chat";
    }
  }

  var args = ["curl", "-s", "-S", "--connect-timeout", "10", "--max-time", "15",
    "-X", "POST", "-H", "Content-Type: application/json",
    "-d", JSON.stringify(payload),
    endpoint
  ];

  return {
    "url": endpoint,
    "payload": JSON.stringify(payload),
    "args": args,
    "isOpenAICompat": isOpenAICompat
  };
}

function parseRephraseResult(responseText) {
  if (!responseText) return "";
  try {
    var json = JSON.parse(responseText.trim());
    if (json.message && json.message.content) {
      return json.message.content.trim();
    }
    if (json.choices && json.choices[0]) {
      if (json.choices[0].message && json.choices[0].message.content) {
        return json.choices[0].message.content.trim();
      }
    }
  } catch (e) {}
  return "";
}

// ===================================
// DuckDuckGo Search (scrape, no API key)
// ===================================

function buildDuckDuckGoSearchCommand(query) {
  return {
    "args": ["curl", "-s", "-S", "--connect-timeout", "5", "--max-time", "10",
      "-L", "https://html.duckduckgo.com/html/?q=" + encodeURIComponent(query)]
  };
}

function parseDuckDuckGoResults(html, maxResults) {
  var results = [];
  if (!html) return results;

  var parts = html.split('class="results_links_deep"');
  for (var i = 1; i < parts.length && results.length < maxResults; i++) {
    var block = parts[i];

    var titleMatch = block.match(/<a[^>]*class="result__a"[^>]*>([\s\S]*?)<\/a>/i);
    var title = titleMatch ? titleMatch[1].replace(/<[^>]*>/g, "").trim() : "";
    if (title === "") continue;

    var snippetMatch = block.match(/<a[^>]*class="result__snippet"[^>]*href="([^"]*)"[^>]*>([\s\S]*?)<\/a>/i);
    if (!snippetMatch) continue;

    var rawUrl = snippetMatch[1];
    var content = snippetMatch[2].replace(/<[^>]*>/g, "").trim();

    var url = rawUrl;
    if (url.indexOf("uddg=") !== -1) {
      var urlParts = url.split("uddg=");
      if (urlParts.length > 1) {
        try {
          url = decodeURIComponent(urlParts[1].split("&")[0]);
        } catch (e) {}
      }
    } else if (url.indexOf("//") === 0) {
      url = "https:" + url;
    }

    results.push({ "title": title, "url": url, "content": content });
  }

  return results;
}

// ===================================
// SearXNG Search (self-hosted, JSON or HTML)
// ===================================

function buildSearxngSearchCommand(instanceUrl, query, jsonMode) {
  var baseUrl = instanceUrl.trim();
  if (baseUrl === "") return null;

  if (baseUrl.endsWith("/")) baseUrl = baseUrl.slice(0, -1);

  var url;
  if (jsonMode) {
    url = baseUrl + "/search?q=" + encodeURIComponent(query) + "&format=json";
  } else {
    url = baseUrl + "/search?q=" + encodeURIComponent(query);
  }

  return {
    "args": ["curl", "-s", "-S", "--connect-timeout", "5", "--max-time", "10", "-L", url],
    "jsonMode": jsonMode
  };
}

function parseSearxngResults(text, maxResults, jsonMode) {
  var results = [];
  if (!text) return results;

  if (jsonMode) {
    try {
      var json = JSON.parse(text);
      if (json.results && Array.isArray(json.results)) {
        for (var i = 0; i < json.results.length && results.length < maxResults; i++) {
          var r = json.results[i];
          if (r.title || r.content) {
            results.push({
              "title": r.title || "",
              "url": r.url || "",
              "content": r.content || ""
            });
          }
        }
      }
    } catch (e) {}
  } else {
    var parts = text.split(/<article[\s>]/gi);
    for (var i = 1; i < parts.length && results.length < maxResults; i++) {
      var block = parts[i];

      var titleMatch = block.match(/<h3[^>]*>([\s\S]*?)<\/h3>/i);
      var title = titleMatch ? titleMatch[1].replace(/<[^>]*>/g, "").trim() : "";

      var urlMatch = block.match(/href="(https?:\/\/[^"]+)"/i);
      var url = urlMatch ? urlMatch[1] : "";

      var contentMatch = block.match(/<p[^>]*>([\s\S]*?)<\/p>/i);
      var content = contentMatch ? contentMatch[1].replace(/<[^>]*>/g, "").trim() : "";

      if (title !== "" || content !== "") {
        results.push({ "title": title, "url": url, "content": content });
      }
    }
  }

  return results;
}

// ===================================
// StartPage Search (scrape, no API key)
// ===================================

function buildStartPageSearchCommand(query) {
  return {
    "args": ["curl", "-s", "-S", "--connect-timeout", "5", "--max-time", "10",
      "-L", "https://www.startpage.com/sp/search?query=" + encodeURIComponent(query)]
  };
}

function parseStartPageResults(html, maxResults) {
  var results = [];
  if (!html) return results;

  var parts = html.split(/class="[^"]*w-gl__result[^"]*"/gi);
  for (var i = 1; i < parts.length && results.length < maxResults; i++) {
    var block = parts[i];

    var titleMatch = block.match(/<a[^>]*>([\s\S]*?)<\/a>/i);
    var title = titleMatch ? titleMatch[1].replace(/<[^>]*>/g, "").trim() : "";
    if (title === "") continue;

    var urlMatch = block.match(/href="(https?:\/\/[^"]+)"/i);
    var url = urlMatch ? urlMatch[1] : "";

    var contentMatch = block.match(/<p[^>]*class="[^"]*w-gl__description[^"]*"[^>]*>([\s\S]*?)<\/p>/i);
    var content = contentMatch ? contentMatch[1].replace(/<[^>]*>/g, "").trim() : "";

    if (title !== "" || content !== "") {
      results.push({ "title": title, "url": url, "content": content });
    }
  }

  return results;
}

// ===================================
// Search Dispatcher
// ===================================

function buildSearchCommand(provider, query, opts) {
  opts = opts || {};
  switch (provider) {
    case "duckduckgo":
      return buildDuckDuckGoSearchCommand(query);
    case "searxng":
      return buildSearxngSearchCommand(opts.searxngUrl || "", query, opts.searxngJsonMode !== false);
    case "startpage":
      return buildStartPageSearchCommand(query);
    default:
      return buildDuckDuckGoSearchCommand(query);
  }
}

function parseSearchResults(provider, text, opts) {
  opts = opts || {};
  var maxResults = opts.maxResults || 5;
  switch (provider) {
    case "duckduckgo":
      return parseDuckDuckGoResults(text, maxResults);
    case "searxng":
      return parseSearxngResults(text, maxResults, opts.searxngJsonMode !== false);
    case "startpage":
      return parseStartPageResults(text, maxResults);
    default:
      return parseDuckDuckGoResults(text, maxResults);
  }
}

// ===================================
// Enhanced System Prompt Builder
// ===================================

function buildEnhancedSystemPrompt(basePrompt, results, query) {
  if (!results || results.length === 0) {
    return basePrompt;
  }

  var now = new Date();
  var dateStr = now.toLocaleDateString("en-US", {
    "weekday": "long", "year": "numeric", "month": "long", "day": "numeric"
  });
  var timeStr = now.toLocaleTimeString("en-US", {
    "hour": "2-digit", "minute": "2-digit"
  });

  var searchResultsXml = "";
  for (var i = 0; i < results.length; i++) {
    var r = results[i];
    var source = r.url ? r.url : "result";
    searchResultsXml += '<result source="' + source.replace(/</g, "<") + '" id="' + i + '">';
    searchResultsXml += (r.content || r.title || "").replace(/</g, "<");
    searchResultsXml += "</result>\n";
  }

  var enhancedPrompt = basePrompt;
  if (enhancedPrompt !== "") enhancedPrompt += "\n\n";

  enhancedPrompt +=
    "Current date and time: " + dateStr + " at " + timeStr + "\n\n" +
    "Web search results for \"" + query.replace(/</g, "<") + "\":\n" +
    "<search-results>\n" +
    searchResultsXml +
    "</search-results>\n\n" +
    "Use the search results above as context for your response. " +
    "When you use information from a specific source, cite it with the source URL.";

  return enhancedPrompt;
}