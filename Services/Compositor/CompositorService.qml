pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.Commons
import qs.Services.Control
import qs.Services.Keyboard
import qs.Services.UI

Singleton {
  id: root

  // ===== PUBLIC INTERFACE =====
  // Mordial targets MangoWC primarily, with brief Niri support.
  // Compositor integration is built on either mmsg IPC (MangoWC)
  // or niri msg (Niri).

  property bool isMango: !!Quickshell.env("MANGO_INSTANCE_SIGNATURE") && !isNiri
  property bool isNiri: !!Quickshell.env("NIRI_SOCKET") || (Quickshell.env("XDG_CURRENT_DESKTOP") || "").toLowerCase().indexOf("niri") !== -1

  property ListModel workspaces: ListModel {}
  property ListModel windows: ListModel {}
  property int focusedWindowIndex: -1
  // Toplevel handles ordered most-recently-focused first. Drives the
  // Alt-Tab switcher's "previously used window" ordering. Not a binding
  // target: consumers snapshot it on open.
  property var focusHistory: []

  property var displayScales: ({})
  property bool displayScalesLoaded: false

  signal workspaceChanged
  signal activeWindowChanged
  signal windowListChanged

  // ===== INTERNAL STATE =====

  QtObject {
    id: internal

    // Latest monitor data from mmsg watch all-monitors
    property var lastMonitorData: null

    // Window-to-tag persistence: Map<UniqueID, TagID>
    property var windowTagMap: ({})

    // Window-to-output persistence: Map<UniqueID, OutputName>
    property var windowOutputMap: ({})

    // Toplevel-to-ID mapping: Map<ToplevelObject, UniqueID>
    property var toplevelIdMap: new Map()
    property int windowIdCounter: 0

    // Output name to index mapping for unique workspace IDs
    property var outputIndices: ({})
    property int outputCounter: 0

    // Monitor scales: Map<OutputName, scale>
    property var monitorScales: ({})

    // Change-detection signatures to avoid needless ListModel churn
    property string lastWindowSignature: ""
    property string lastWorkspaceSignature: ""

    // Niri: window count per workspace id, derived from `niri msg --json windows`.
    // Niri's workspace JSON has no occupancy field (only active_window_id), so
    // this map is the authoritative source for the "occupied" pill state.
    property var niriWindowCounts: ({})

    // Niri: last raw workspaces payload. Cached so occupancy can be recomputed
    // when the window list arrives or changes, without re-querying niri.
    property var lastNiriWorkspaces: []

    // ===== REBUILD WORKSPACES FROM MMSG DATA =====

    function rebuildWorkspaces() {
      if (!internal.lastMonitorData || !internal.lastMonitorData.monitors) {
        Logger.w("CompositorService", "rebuildWorkspaces: no monitor data available");
        return;
      }

      const monitors = internal.lastMonitorData.monitors;
      const workspaceList = [];

      for (let mi = 0; mi < monitors.length; mi++) {
        const mon = monitors[mi];
        const outputName = mon.name;

        // Assign stable index to output
        if (internal.outputIndices[outputName] === undefined) {
          internal.outputIndices[outputName] = internal.outputCounter++;
        }
        const outputIdx = internal.outputIndices[outputName];

        // Track the active monitor (used as fallback output name)
        if (mon.active) {
          root.selectedMonitor = outputName;
        }

        // Store scale
        if (typeof mon.scale === "number") {
          internal.monitorScales[outputName] = mon.scale;
        }

        const tags = mon.tags || [];
        const activeTags = mon.active_tags || [];
        for (let ti = 0; ti < tags.length; ti++) {
          const tag = tags[ti];
          const tagId = tag.index; // mmsg tags are 1-based
          const uniqueId = outputIdx * 100 + tagId;

          workspaceList.push({
                               id: uniqueId,
                               idx: tagId,
                               name: tagId.toString(),
                               output: outputName,
                               isActive: activeTags.includes(tagId),
                               isFocused: tag.is_active && mon.active,
                               isUrgent: tag.is_urgent,
                               isOccupied: tag.client_count > 0
                             });
        }
      }

      // Sort by unique ID
      workspaceList.sort((a, b) => a.id - b.id);

      // Only churn the model when the workspace state actually changed
      const signature = JSON.stringify(workspaceList.map(w => w.id + "|" + w.isActive + "|" + w.isFocused + "|" + w.isUrgent + "|" + w.isOccupied));
      if (signature === internal.lastWorkspaceSignature) {
        return;
      }
      internal.lastWorkspaceSignature = signature;

      root.workspaces.clear();
      for (let k = 0; k < workspaceList.length; k++) {
        root.workspaces.append(workspaceList[k]);
      }

      root.workspaceChanged();
      if (workspaceList.length > 0) {
        Logger.d("CompositorService", "Rebuilt", workspaceList.length, "workspaces from", monitors.length, "monitors");
      }
    }

    // ===== NIRI EVENT HANDLERS =====

    function handleNiriEvent(data) {
      if (!data)
        return;
      const keys = Object.keys(data);
      for (let i = 0; i < keys.length; i++) {
        const k = keys[i];
        if (k.indexOf("Workspace") !== -1) {
          queryNiriWorkspaces();
          break;
        }
        if (k.indexOf("Window") !== -1) {
          queryNiriWindows();
          break;
        }
        if (k.indexOf("Keyboard") !== -1 || k.indexOf("Layout") !== -1) {
          queryNiriKeyboardLayout();
          break;
        }
      }
      // Also refresh
      queryNiriWorkspaces();
      queryNiriWindows();
      queryNiriKeyboardLayout();
    }

    function queryNiriWorkspaces() {
      niriQueryProc.command = ["niri", "msg", "--json", "workspaces"];
      niriQueryProc.running = true;
    }

    function queryNiriWindows() {
      // Windows come via "windows" command
      const proc = niriWindowsProc;
      proc.command = ["niri", "msg", "--json", "windows"];
      proc.running = true;
    }

    function queryNiriKeyboardLayout() {
      niriKbProc.command = ["niri", "msg", "--json", "keyboard-layouts"];
      niriKbProc.running = true;
    }

    function processNiriWorkspaces(workspacesData) {
      if (!workspacesData)
        return;
      const wsList = Array.isArray(workspacesData) ? workspacesData : (workspacesData.workspaces || []);
      internal.lastNiriWorkspaces = wsList;
      const list = [];
      for (let i = 0; i < wsList.length; i++) {
        const ws = wsList[i];
        const idx = ws.idx !== undefined ? ws.idx : (ws.id !== undefined ? ws.id : i + 1);
        const output = ws.output || ws.monitor || "";
        // Occupancy: prefer the count derived from `niri msg windows`. Fall back
        // to active_window_id while the window list has not been loaded yet.
        const windowCount = internal.niriWindowCounts[String(ws.id)] || 0;
        const hasActiveWindow = ws.active_window_id !== undefined && ws.active_window_id !== null;
        list.push({
                    id: ws.id !== undefined ? ws.id : idx,
                    idx: idx,
                    name: ws.name !== undefined ? ws.name : idx.toString(),
                    output: output,
                    isActive: !!(ws.is_active || ws.active || ws.focused),
                    isFocused: !!(ws.is_focused || ws.focused || ws.is_active),
                    isUrgent: !!ws.is_urgent,
                    isOccupied: windowCount > 0 || hasActiveWindow
                  });
      }
      list.sort((a, b) => (a.idx || 0) - (b.idx || 0));
      const signature = JSON.stringify(list.map(w => w.id + "|" + w.isActive + "|" + w.isFocused + "|" + w.isUrgent + "|" + w.isOccupied));
      if (signature === internal.lastWorkspaceSignature) {
        return;
      }
      internal.lastWorkspaceSignature = signature;
      root.workspaces.clear();
      for (let k = 0; k < list.length; k++) {
        root.workspaces.append(list[k]);
      }
      root.workspaceChanged();
    }

    function processNiriWindows(windowsData) {
      if (!windowsData)
        return;
      const winList = Array.isArray(windowsData) ? windowsData : (windowsData.windows || []);
      const list = [];
      // Rebuilt from scratch on every poll so closed windows drop out cleanly.
      const countByWorkspace = {};
      let newFocusedIdx = -1;
      for (let i = 0; i < winList.length; i++) {
        const w = winList[i];
        const isFocused = !!(w.is_focused || w.focused);
        if (isFocused && newFocusedIdx === -1) {
          newFocusedIdx = i;
        }
        const wsId = w.workspace_id !== undefined && w.workspace_id !== null ? w.workspace_id : w.workspaceId;
        if (wsId !== undefined && wsId !== null) {
          const key = String(wsId);
          countByWorkspace[key] = (countByWorkspace[key] || 0) + 1;
        }
        list.push({
                    id: w.id,
                    address: w.id,
                    title: w.title || "",
                    appId: w.app_id || w.appId || w.class || "",
                    class: w.app_id || w.appId || w.class || "",
                    isFocused: isFocused,
                    workspaceId: wsId,
                    output: w.output || "",
                    handle: null
                  });
      }
      internal.niriWindowCounts = countByWorkspace;

      // Include workspaceId: moving a window between workspaces changes neither
      // its title nor its appId, yet the grouped bar view and the occupied
      // state must update.
      const signature = JSON.stringify(list.map(w => w.id + w.title + w.appId + w.isFocused + w.workspaceId));
      if (signature !== internal.lastWindowSignature) {
        internal.lastWindowSignature = signature;
        root.windows.clear();
        for (let k = 0; k < list.length; k++) {
          root.windows.append(list[k]);
        }
        root.windowListChanged();
      }
      if (newFocusedIdx !== root.focusedWindowIndex) {
        root.focusedWindowIndex = newFocusedIdx;
        root.activeWindowChanged();
      }

      // Occupancy lives on the workspace model, so re-derive it now that the
      // per-workspace window counts are fresh (no extra niri query needed).
      if (internal.lastNiriWorkspaces.length > 0) {
        internal.processNiriWorkspaces(internal.lastNiriWorkspaces);
      }
    }

    function processNiriKeyboardLayout(data) {
      if (!data)
        return;
      let layoutStr = "";
      if (typeof data === "string") {
        layoutStr = data;
      } else if (data.current_layout_name) {
        layoutStr = data.current_layout_name;
      } else if (data.current) {
        layoutStr = data.current;
      } else if (data.names && Array.isArray(data.names)) {
        const idx = typeof data.current_idx === "number" ? data.current_idx : (typeof data.current === "number" ? data.current : 0);
        layoutStr = data.names[idx] || data.names[0] || "";
      } else if (data.layouts && Array.isArray(data.layouts)) {
        const idx = typeof data.current_idx === "number" ? data.current_idx : 0;
        const l = data.layouts[idx] || data.layouts[0];
        if (l) {
          layoutStr = l.name || l.short_name || l.shortName || l.xkb_layout || "";
        }
      }
      if (layoutStr && layoutStr.length > 0) {
        KeyboardLayoutService.setCurrentLayout(layoutStr);
      }
    }

    property QtObject _niriWindowsProc: Process {
      id: niriWindowsProc
      command: ["niri", "msg", "--json", "windows"]
      running: false

      property string buffer: ""
      stdout: SplitParser {
        onRead: line => {
          niriWindowsProc.buffer += line;
        }
      }
      onRunningChanged: {
        if (running) {
          niriWindowsProc.buffer = "";
        } else if (niriWindowsProc.buffer.length > 0) {
          const txt = niriWindowsProc.buffer;
          try {
            const data = JSON.parse(txt);
            if (Array.isArray(data)) {
              internal.processNiriWindows(data);
            } else if (data && data.windows && Array.isArray(data.windows)) {
              internal.processNiriWindows(data.windows);
            } else {
              internal.processNiriWindows(data);
            }
          } catch (e) {
            // ignore
          }
          niriWindowsProc.buffer = "";
        }
      }
    }

    // ===== UPDATE WINDOWS =====

    function updateWindows() {
      if (!ToplevelManager.toplevels) {
        Logger.w("CompositorService", "updateWindows: ToplevelManager.toplevels is null");
        return;
      }
      if (!internal.lastMonitorData || !internal.lastMonitorData.monitors) {
        Logger.w("CompositorService", "updateWindows: no monitor data available");
        return;
      }

      const monitors = internal.lastMonitorData.monitors;
      const toplevels = ToplevelManager.toplevels.values;
      const windowList = [];
      let newFocusedIdx = -1;
      let focusedToplevel = null;
      const currentWindows = new Set();

      // Build per-output state from mmsg data
      // Map<outputName, { title, appId, activeTagId }>
      const outputState = {};
      for (let mi = 0; mi < monitors.length; mi++) {
        const mon = monitors[mi];
        const outputName = mon.name;

        // Find first active tag
        let activeTagId = 1;
        const activeTags = mon.active_tags || [];
        if (activeTags.length > 0) {
          activeTagId = activeTags[0];
        }

        const ac = mon.active_client;
        outputState[outputName] = {
          title: ac ? (ac.title || "") : "",
          appId: ac ? (ac.appid || "") : "",
          activeTagId: activeTagId
        };

        // Ensure output index exists
        if (internal.outputIndices[outputName] === undefined) {
          internal.outputIndices[outputName] = internal.outputCounter++;
        }
      }

      for (let i = 0; i < toplevels.length; i++) {
        const toplevel = toplevels[i];
        if (!toplevel || toplevel.outliers) {
          continue;
        }

        const appId = toplevel.appId || toplevel.wayland?.appId || "";
        const title = toplevel.title || toplevel.wayland?.title || "";
        const isFocused = toplevel.activated;

        // Get or assign a stable ID
        let windowId;
        if (internal.toplevelIdMap.has(toplevel)) {
          windowId = internal.toplevelIdMap.get(toplevel);
        } else {
          windowId = `win-${internal.windowIdCounter++}`;
          internal.toplevelIdMap.set(toplevel, windowId);
        }

        currentWindows.add(windowId);

        // Determine output
        let outputName;

        // Priority 1: Focused window matched to mmsg output metadata
        if (isFocused && (title || appId)) {
          for (const oName in outputState) {
            const os = outputState[oName];
            if ((os.title || os.appId) && title === os.title && appId === os.appId) {
              outputName = oName;
              internal.windowOutputMap[windowId] = oName;
              break;
            }
          }
        }

        // Priority 2: Remembered output
        if (!outputName && internal.windowOutputMap[windowId]) {
          outputName = internal.windowOutputMap[windowId];
        }

        // Priority 3: toplevel.screens (wlr-foreign-toplevel visible screens)
        if (!outputName && toplevel.screens && toplevel.screens.length > 0) {
          outputName = toplevel.screens[0].name;
        }

        // Fallback: selected monitor
        if (!outputName) {
          outputName = root.selectedMonitor || "HDMI-A-1";
        }

        // Determine tag
        let tagId = null;

        const os = outputState[outputName];
        if (isFocused && os && !os.consumed && (os.title || os.appId) && title === os.title && appId === os.appId) {
          // Focused window: assign to the active tag from mmsg metadata
          tagId = os.activeTagId;
          internal.windowTagMap[windowId] = tagId;
          // Consume so a second toplevel with identical title+appId cannot also claim focus
          os.consumed = true;
        } else if (internal.windowTagMap[windowId] !== undefined) {
          // Previously seen window: use remembered tag
          tagId = internal.windowTagMap[windowId];
        }

        if (tagId === null) {
          // Can't determine the tag for unfocused windows until they gain focus.
          continue;
        }

        // Convert to unique workspace ID
        const outputIdx = internal.outputIndices[outputName];
        if (outputIdx === undefined) {
          Logger.e("CompositorService", "No output index for", outputName);
          continue;
        }
        const workspaceId = outputIdx * 100 + tagId;

        windowList.push({
                          id: `${outputName}:${appId}:${title}:${i}`,
                          title: title,
                          appId: appId,
                          class: appId,
                          workspaceId: workspaceId,
                          isFocused: isFocused,
                          output: outputName,
                          handle: toplevel,
                          fullscreen: toplevel.fullscreen || false,
                          floating: toplevel.maximized === false && toplevel.fullscreen === false
                        });

        if (isFocused) {
          newFocusedIdx = windowList.length - 1;
          focusedToplevel = toplevel;
        }
      }

      // Update most-recently-focused ordering for the Alt-Tab switcher.
      // Drop handles for windows that closed, then move the focused window to
      // the front. Reassign only on change so bindings don't churn.
      const liveHandles = new Set(windowList.map(w => w.handle));
      let history = root.focusHistory;
      if (history.some(h => !liveHandles.has(h))) {
        history = history.filter(h => liveHandles.has(h));
      }
      if (focusedToplevel && history[0] !== focusedToplevel) {
        history = [focusedToplevel].concat(history.filter(h => h !== focusedToplevel));
        if (history.length > 64) {
          history = history.slice(0, 64);
        }
      }
      if (history !== root.focusHistory) {
        root.focusHistory = history;
      }

      // Clean up stale window tracking
      if (Object.keys(internal.windowTagMap).length > toplevels.length + 20) {
        const newTagMap = {};
        const newOutputMap = {};
        for (const windowId of currentWindows) {
          if (internal.windowTagMap[windowId] !== undefined) {
            newTagMap[windowId] = internal.windowTagMap[windowId];
          }
          if (internal.windowOutputMap[windowId] !== undefined) {
            newOutputMap[windowId] = internal.windowOutputMap[windowId];
          }
        }
        internal.windowTagMap = newTagMap;
        internal.windowOutputMap = newOutputMap;
      }

      // Check if window list changed
      const signature = JSON.stringify(windowList.map(w => w.id + w.workspaceId + w.isFocused));
      if (signature !== internal.lastWindowSignature) {
        internal.lastWindowSignature = signature;
        root.windows.clear();
        for (const w of windowList) {
          root.windows.append(w);
        }
        root.windowListChanged();
        Logger.d("CompositorService", "Window list updated:", windowList.length, "windows,", toplevels.length, "toplevels");
      }

      if (newFocusedIdx !== root.focusedWindowIndex) {
        root.focusedWindowIndex = newFocusedIdx;
        root.activeWindowChanged();
      }
    }

    // ===== PROCESS MONITOR SCALES =====

    function processMonitorScales(monitors) {
      const scalesMap = {};
      for (let i = 0; i < monitors.length; i++) {
        const mon = monitors[i];
        if (mon.name && typeof mon.scale === "number") {
          internal.monitorScales[mon.name] = mon.scale;
          scalesMap[mon.name] = {
            name: mon.name,
            scale: mon.scale
          };
        }
      }

      root.onDisplayScalesUpdated(scalesMap);
    }
  }

  // ===== MMSG WATCH PROCESSES (persistent streams) =====

  property string selectedMonitor: ""

  property QtObject _mmsgWatch: Process {
    id: mmsgWatch
    command: ["mmsg", "watch", "all-monitors"]
    running: root.initialized && !root.isNiri

    stdout: SplitParser {
      onRead: line => {
        const trimmed = line.trim();
        if (trimmed.length === 0)
        return;
        try {
          const data = JSON.parse(trimmed);
          if (data.monitors && Array.isArray(data.monitors)) {
            internal.lastMonitorData = data;
            internal.processMonitorScales(data.monitors);
            internal.rebuildWorkspaces();
            internal.updateWindows();
          }
        } catch (e) {
          Logger.e("CompositorService", "Failed to parse mmsg watch output:", e);
        }
      }
    }

    onRunningChanged: {
      if (!running && root.initialized) {
        Logger.w("CompositorService", "mmsg watch process exited, restarting in 1s");
        restartTimer.restart();
      }
    }
  }

  property QtObject _restartTimer: Timer {
    id: restartTimer
    interval: 1000
    onTriggered: {
      if (root.initialized && !mmsgWatch.running) {
        Logger.i("CompositorService", "Restarting mmsg watch");
        mmsgWatch.running = true;
      }
    }
  }

  // Keyboard layout - MangoWC doesn't send events for XKB-driven
  // layout switches (grp:win_space_toggle), so we keep a persistent
  // `mmsg watch keyboardlayout` stream instead of polling.
  property QtObject _kbLayoutWatch: Process {
    id: kbLayoutWatch
    command: ["mmsg", "watch", "keyboardlayout"]
    running: root.initialized && !root.isNiri

    stdout: SplitParser {
      onRead: line => {
        const trimmed = line.trim();
        if (trimmed.length === 0)
        return;
        try {
          const data = JSON.parse(trimmed);
          const layout = String(data.layout ?? "").trim();
          if (layout.length > 0) {
            KeyboardLayoutService.setCurrentLayout(layout);
            Logger.d("CompositorService", "Keyboard layout:", layout);
          }
        } catch (e) {
          Logger.e("CompositorService", "Failed to parse keyboard layout JSON:", e);
        }
      }
    }

    onRunningChanged: {
      if (!running && root.initialized) {
        Logger.w("CompositorService", "mmsg watch keyboardlayout exited, restarting in 1s");
        kbLayoutRestartTimer.restart();
      }
    }
  }

  property QtObject _kbLayoutRestartTimer: Timer {
    id: kbLayoutRestartTimer
    interval: 1000
    onTriggered: {
      if (root.initialized && !kbLayoutWatch.running) {
        Logger.i("CompositorService", "Restarting mmsg keyboardlayout watch");
        kbLayoutWatch.running = true;
      }
    }
  }

  property QtObject _niriQueryProc: Process {
    id: niriQueryProc
    command: ["niri", "msg", "--json", "workspaces"]
    running: false

    property string buffer: ""
    stdout: SplitParser {
      onRead: line => {
        niriQueryProc.buffer += line;
      }
    }
    onRunningChanged: {
      if (running) {
        niriQueryProc.buffer = "";
      } else if (niriQueryProc.buffer.length > 0) {
        const txt = niriQueryProc.buffer;
        try {
          const data = JSON.parse(txt);
          if (Array.isArray(data)) {
            internal.processNiriWorkspaces(data);
          } else if (data && data.workspaces && Array.isArray(data.workspaces)) {
            internal.processNiriWorkspaces(data.workspaces);
          } else {
            internal.processNiriWorkspaces(data);
          }
        } catch (e) {
          // ignore
        }
        niriQueryProc.buffer = "";
      }
    }
  }

  property QtObject _niriKbProc: Process {
    id: niriKbProc
    command: ["niri", "msg", "--json", "keyboard-layouts"]
    running: false

    property string buffer: ""
    stdout: SplitParser {
      onRead: line => {
        niriKbProc.buffer += line;
      }
    }
    onRunningChanged: {
      if (running) {
        niriKbProc.buffer = "";
      } else if (niriKbProc.buffer.length > 0) {
        const txt = niriKbProc.buffer;
        try {
          const data = JSON.parse(txt);
          internal.processNiriKeyboardLayout(data);
        } catch (e) {
          // ignore
        }
        niriKbProc.buffer = "";
      }
    }
  }

  // ===== NIRI SUPPORT =====
  property QtObject _niriEventStream: Process {
    id: niriEventStream
    command: ["niri", "msg", "--json", "event-stream"]
    running: root.initialized && root.isNiri

    stdout: SplitParser {
      onRead: line => {
        const trimmed = line.trim();
        if (trimmed.length === 0)
        return;
        try {
          const data = JSON.parse(trimmed);
          internal.handleNiriEvent(data);
        } catch (e) {
          Logger.e("CompositorService", "Failed to parse niri event:", e);
        }
      }
    }

    onRunningChanged: {
      if (!running && root.initialized && root.isNiri) {
        Logger.w("CompositorService", "niri event-stream exited, restarting in 1s");
        niriEventRestartTimer.restart();
      }
    }
  }

  property QtObject _niriEventRestartTimer: Timer {
    id: niriEventRestartTimer
    interval: 1000
    onTriggered: {
      if (root.initialized && root.isNiri && !niriEventStream.running) {
        Logger.i("CompositorService", "Restarting niri event-stream");
        niriEventStream.running = true;
      }
    }
  }

  property QtObject _niriWorkspacesTimer: Timer {
    id: niriWorkspacesTimer
    interval: 2000
    repeat: true
    running: false
    onTriggered: {
      if (root.isNiri) {
        internal.queryNiriWorkspaces();
      }
    }
  }

  property QtObject _niriWindowsTimer: Timer {
    id: niriWindowsTimer
    interval: 1500
    repeat: true
    running: false
    onTriggered: {
      if (root.isNiri) {
        internal.queryNiriWindows();
      }
    }
  }

  // ===== TOPLEVEL MANAGER CONNECTION =====

  property QtObject _toplevelConnection: Connections {
    target: ToplevelManager.toplevels
    enabled: ToplevelManager.toplevels !== null && ToplevelManager.toplevels !== undefined && !root.isNiri

    function onValuesChanged() {
      internal.updateWindows();
    }
  }

  // ===== LIFECYCLE =====

  property bool initialized: false

  Component.onCompleted: {
    Qt.callLater(() => {
                   if (typeof ShellState !== 'undefined' && ShellState.isLoaded) {
                     loadDisplayScalesFromState();
                   }
                 });
    initialize();
  }

  Connections {
    target: typeof ShellState !== 'undefined' ? ShellState : null
    function onIsLoadedChanged() {
      if (ShellState.isLoaded) {
        loadDisplayScalesFromState();
      }
    }
  }

  function initialize() {
    if (initialized) {
      return;
    }

    if (root.isNiri) {
      Logger.i("CompositorService", "Initializing Niri compositor integration (niri msg)");
      Logger.i("CompositorService", "ToplevelManager.toplevels:", ToplevelManager.toplevels ? "available" : "null");
      Logger.i("CompositorService", "Quickshell.screens count:", Quickshell.screens ? Quickshell.screens.length : 0);

      if (!Quickshell.env("NIRI_SOCKET")) {
        Logger.w("CompositorService", "NIRI_SOCKET not set - niri integration may fail");
      }

      niriEventStream.running = true;
      niriWorkspacesTimer.start();
      niriWindowsTimer.start();
      internal.queryNiriWorkspaces();
      internal.queryNiriWindows();
      internal.queryNiriKeyboardLayout();
      initialized = true;
      return;
    }

    Logger.i("CompositorService", "Initializing MangoWC compositor integration (mmsg IPC)");
    Logger.i("CompositorService", "ToplevelManager.toplevels:", ToplevelManager.toplevels ? "available" : "null");
    Logger.i("CompositorService", "Quickshell.screens count:", Quickshell.screens ? Quickshell.screens.length : 0);

    if (!Quickshell.env("MANGO_INSTANCE_SIGNATURE")) {
      Logger.e("CompositorService", "MANGO_INSTANCE_SIGNATURE not set - this shell only supports MangoWC. mmsg IPC will fail.");
    }

    // Start persistent mmsg watch streams
    mmsgWatch.running = true;
    kbLayoutWatch.running = true;

    initialized = true;
  }

  function loadDisplayScalesFromState() {
    try {
      const cached = ShellState.getDisplay();
      if (cached && Object.keys(cached).length > 0) {
        displayScales = cached;
        displayScalesLoaded = true;
        Logger.d("CompositorService", "Loaded display scales from ShellState");
      } else {
        displayScalesLoaded = true;
      }
    } catch (error) {
      Logger.e("CompositorService", "Failed to load display scales:", error);
      displayScalesLoaded = true;
    }
  }

  function updateDisplayScales() {
    queryDisplayScales();
  }

  function queryDisplayScales() {
    // Scales are pushed continuously via the all-monitors watch stream.
    if (internal.lastMonitorData && internal.lastMonitorData.monitors) {
      internal.processMonitorScales(internal.lastMonitorData.monitors);
    }
  }

  function onDisplayScalesUpdated(scales) {
    displayScales = scales;
    saveDisplayScalesToCache();
    Logger.d("CompositorService", "Display scales updated");
  }

  function saveDisplayScalesToCache() {
    try {
      ShellState.setDisplay(displayScales);
    } catch (error) {
      Logger.e("CompositorService", "Failed to save display scales:", error);
    }
  }

  function getDisplayScale(displayName) {
    if (!displayName || !displayScales[displayName])
      return 1.0;
    return displayScales[displayName].scale || 1.0;
  }

  function getDisplayInfo(displayName) {
    if (!displayName || !displayScales[displayName])
      return null;
    return displayScales[displayName];
  }

  function getFocusedWindow() {
    if (focusedWindowIndex >= 0 && focusedWindowIndex < windows.count) {
      return windows.get(focusedWindowIndex);
    }
    return null;
  }

  function getFocusedScreen() {
    return null;
  }

  function getFocusedWindowTitle() {
    if (focusedWindowIndex >= 0 && focusedWindowIndex < windows.count) {
      var title = windows.get(focusedWindowIndex).title;
      if (title !== undefined)
        title = title.replace(/(\r\n|\n|\r)/g, "");
      return title || "";
    }
    return "";
  }

  function getCleanAppName(appId, fallbackTitle) {
    var name = (appId || "").split(".").pop() || fallbackTitle || "Unknown";
    return name.charAt(0).toUpperCase() + name.slice(1);
  }

  function getWindowsForWorkspace(workspaceId) {
    var windowsInWs = [];
    for (var i = 0; i < windows.count; i++) {
      var window = windows.get(i);
      if (window.workspaceId === workspaceId) {
        windowsInWs.push({
                           id: window.id,
                           title: window.title,
                           appId: window.appId,
                           isFocused: window.isFocused,
                           workspaceId: window.workspaceId,
                           handle: window.handle
                         });
      }
    }
    return windowsInWs;
  }

  function switchToWorkspace(workspace) {
    if (root.isNiri) {
      const wsId = workspace.id !== undefined ? workspace.id : (workspace.idx || 1);
      Quickshell.execDetached(["niri", "msg", "action", "focus-workspace", wsId.toString()]);
      return;
    }
    const tagId = workspace.idx || workspace.id || 1;
    const outputName = workspace.output || root.selectedMonitor || "";

    let cmd = ["mmsg", "dispatch", "view," + tagId.toString()];
    if (outputName && Object.keys(internal.monitorScales).length > 1) {
      cmd.push("monitor," + outputName);
    }
    Quickshell.execDetached(cmd);
  }

  function getCurrentWorkspace() {
    for (var i = 0; i < workspaces.count; i++) {
      const ws = workspaces.get(i);
      if (ws.isFocused)
        return ws;
    }
    return null;
  }

  function getActiveWorkspaces() {
    const activeWorkspaces = [];
    for (var i = 0; i < workspaces.count; i++) {
      const ws = workspaces.get(i);
      if (ws.isActive)
        activeWorkspaces.push(ws);
    }
    return activeWorkspaces;
  }

  function focusWindow(window) {
    if (!window)
      return;
    if (root.isNiri) {
      if (window.id !== undefined && window.id !== null) {
        Quickshell.execDetached(["niri", "msg", "action", "focus-window", "--id", window.id.toString()]);
        return;
      }
      if (window.appId) {
        // Try to focus by title/app - fallback
      }
      return;
    }
    if (window.handle) {
      window.handle.activate();
    } else if (window.workspaceId) {
      switchToWorkspace({
                          id: window.workspaceId,
                          output: window.output
                        });
    }
  }

  function closeWindow(window) {
    if (root.isNiri) {
      if (window && window.id !== undefined && window.id !== null) {
        Quickshell.execDetached(["niri", "msg", "action", "close-window", "--id", window.id.toString()]);
        return;
      }
      Quickshell.execDetached(["niri", "msg", "action", "close-window"]);
      return;
    }
    if (window && window.handle) {
      window.handle.close();
    } else {
      Quickshell.execDetached(["mmsg", "dispatch", "killclient"]);
    }
  }

  function spawn(command) {
    const cmdArray = Array.isArray(command) ? command : (command && typeof command === "object" && command.length !== undefined) ? Array.from(command) : [command];

    Logger.d("CompositorService", "Spawning: " + cmdArray.join(" "));
    if (root.isNiri) {
      try {
        Quickshell.execDetached(cmdArray);
        return;
      } catch (e) {
        Logger.e("CompositorService", "Failed to execute detached:", e);
        return;
      }
    }
    try {
      const cmd = ["mmsg", "dispatch", "spawn_shell," + cmdArray.join(" ")];
      Quickshell.execDetached(cmd);
    } catch (e) {
      Logger.e("CompositorService", "Failed to spawn command:", e);
      try {
        Quickshell.execDetached(cmdArray);
      } catch (e2) {
        Logger.e("CompositorService", "Failed to execute detached:", e2);
      }
    }
  }

  function getCustomCommand(action) {
    const powerOptions = Settings.data.sessionMenu.powerOptions || [];
    for (let i = 0; i < powerOptions.length; i++) {
      const option = powerOptions[i];
      if (option.action === action && option.enabled && option.command && option.command.trim() !== "") {
        return option.command.trim();
      }
    }
    return "";
  }

  function executeSessionAction(action, defaultCommand) {
    const customCommand = getCustomCommand(action);
    if (customCommand) {
      Logger.i("Compositor", "Executing custom command for action: " + action + " Command: " + customCommand);
      Quickshell.execDetached(["sh", "-c", customCommand]);
      return true;
    }
    return false;
  }

  function logout() {
    Logger.i("Compositor", "Logout requested");
    if (executeSessionAction("logout"))
      return;
    if (root.isNiri) {
      Quickshell.execDetached(["niri", "msg", "action", "quit"]);
      return;
    }
    Quickshell.execDetached(["mmsg", "dispatch", "quit"]);
  }

  function shutdown() {
    Logger.i("Compositor", "Shutdown requested");
    if (executeSessionAction("shutdown"))
      return;
    HooksService.executeSessionHook("shutdown", () => {
                                      Quickshell.execDetached(["sh", "-c", "systemctl poweroff || loginctl poweroff"]);
                                    });
  }

  function reboot() {
    Logger.i("Compositor", "Reboot requested");
    if (executeSessionAction("reboot"))
      return;
    HooksService.executeSessionHook("reboot", () => {
                                      Quickshell.execDetached(["sh", "-c", "systemctl reboot || loginctl reboot"]);
                                    });
  }

  function userspaceReboot() {
    Logger.i("Compositor", "Userspace reboot requested");
    if (executeSessionAction("userspaceReboot"))
      return;
    HooksService.executeSessionHook("userspaceReboot", () => {
                                      Quickshell.execDetached(["sh", "-c", "systemctl soft-reboot"]);
                                    });
  }

  function rebootToUefi() {
    Logger.i("Compositor", "Reboot to UEFI firmware requested");
    if (executeSessionAction("rebootToUefi"))
      return;
    HooksService.executeSessionHook("rebootToUefi", () => {
                                      Quickshell.execDetached(["sh", "-c", "systemctl reboot --firmware-setup || loginctl reboot --firmware-setup"]);
                                    });
  }

  function turnOffMonitors() {
    Logger.i("Compositor", "Turn off monitors requested");
    Logger.w("Compositor", "MangoWC backend does not support monitor power off");
  }

  function turnOnMonitors() {
    Logger.i("Compositor", "Turn on monitors requested");
    Logger.w("Compositor", "MangoWC backend does not support monitor power on");
  }

  function suspend() {
    Logger.i("Compositor", "Suspend requested");
    if (executeSessionAction("suspend"))
      return;
    Quickshell.execDetached(["sh", "-c", "systemctl suspend || loginctl suspend"]);
  }

  function lock() {
    Logger.i("Compositor", "LockScreen requested");
    if (executeSessionAction("lock"))
      return;
    if (PanelService && PanelService.lockScreen) {
      PanelService.lockScreen.active = true;
    }
  }

  function hibernate() {
    Logger.i("Compositor", "Hibernate requested");
    if (executeSessionAction("hibernate"))
      return;
    Quickshell.execDetached(["sh", "-c", "systemctl hibernate || loginctl hibernate"]);
  }

  function cycleKeyboardLayout() {
    if (root.isNiri) {
      Quickshell.execDetached(["niri", "msg", "action", "switch-layout", "next"]);
      return;
    }
    Quickshell.execDetached(["mmsg", "dispatch", "switch_keyboard_layout"]);
  }

  property int lockAndSuspendCheckCount: 0

  function lockAndSuspend() {
    Logger.i("Compositor", "Lock and suspend requested");
    if (executeSessionAction("lock")) {
      suspend();
      return;
    }
    if (PanelService && PanelService.lockScreen && PanelService.lockScreen.active) {
      Logger.i("Compositor", "Screen already locked, suspending");
      suspend();
      return;
    }
    try {
      if (PanelService && PanelService.lockScreen) {
        PanelService.lockScreen.active = true;
        lockAndSuspendCheckCount = 0;
        lockAndSuspendTimer.start();
      } else {
        Logger.w("Compositor", "Lock screen not available, suspending without lock");
        suspend();
      }
    } catch (e) {
      Logger.w("Compositor", "Failed to activate lock screen before suspend: " + e);
      suspend();
    }
  }

  Timer {
    id: lockAndSuspendTimer
    interval: 100
    repeat: true
    running: false
    onTriggered: {
      lockAndSuspendCheckCount++;
      if (PanelService && PanelService.lockScreen && PanelService.lockScreen.active) {
        if (PanelService.lockScreen.item) {
          Logger.i("Compositor", "Lock screen confirmed active, suspending");
          stop();
          lockAndSuspendCheckCount = 0;
          suspend();
        } else {
          if (lockAndSuspendCheckCount > 20) {
            Logger.w("Compositor", "Lock screen active but component not loaded, suspending anyway");
            stop();
            lockAndSuspendCheckCount = 0;
            suspend();
          }
        }
      } else {
        if (lockAndSuspendCheckCount > 30) {
          Logger.w("Compositor", "Lock screen failed to activate, suspending anyway");
          stop();
          lockAndSuspendCheckCount = 0;
          suspend();
        }
      }
    }
  }
}
