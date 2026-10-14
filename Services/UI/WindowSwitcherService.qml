pragma Singleton

import QtQuick
import Quickshell
import qs.Commons
import qs.Services.Compositor

// Alt-Tab style window switcher state.
// Driven by the `switcher` IPC target (bound in MangoWC) and rendered by
// WindowSwitcherOverlayWindow. Keeps a stable snapshot of the window list
// while open so selection does not shift under the user's fingers.
//
// Flow: hold Alt -> `next`/`previous` per Tab -> release Tab -> `commit`.
// (MangoWC only fires a release bind for the last key pressed, so the commit
// is bound to Tab release rather than Alt release.)
Singleton {
  id: root

  property bool isOpen: false
  property var screen: null
  property int selectedIndex: 0
  // Snapshot: [{ handle, windowId, title, appId, icon, output, workspaceId, isFocused }]
  property var items: []

  // Safety net: normally the compositor's Tab-release bind commits. This only
  // fires if that release is missed (e.g. Alt released before Tab, so the
  // release bind's modifier no longer matches).
  property QtObject _safetyTimer: Timer {
    id: safetyTimer
    interval: 1500
    repeat: false
    onTriggered: root.commit()
  }

  /** Focus the next window, opening the switcher if it is closed. */
  function next() // Cycle selection forward
  {
    if (!isOpen) {
      open(1);
    } else if (items.length > 0) {
      selectedIndex = (selectedIndex + 1) % items.length;
      safetyTimer.restart();
    }
  }

  /** Focus the previous window, opening the switcher if it is closed. */
  function previous() // Cycle selection backward
  {
    if (!isOpen) {
      open(-1);
    } else if (items.length > 0) {
      selectedIndex = (selectedIndex - 1 + items.length) % items.length;
      safetyTimer.restart();
    }
  }

  /** Open the switcher, preselecting the first target in `direction`. */
  function open(direction) // Open overlay with initial selection
  {
    items = buildItems();
    if (items.length === 0) {
      return;
    }

    screen = focusedScreen();
    if (items.length === 1) {
      selectedIndex = 0;
    } else if (direction < 0) {
      selectedIndex = items.length - 1;
    } else {
      selectedIndex = 1;
    }
    isOpen = true;
    safetyTimer.restart();
  }

  /** Focus the selected window and close. */
  function commit() // Apply selection
  {
    if (!isOpen) {
      return;
    }
    var item = items[selectedIndex];
    close();
    if (item && item.handle) {
      CompositorService.focusWindow({
                                      "handle": item.handle,
                                      "workspaceId": item.workspaceId,
                                      "output": item.output
                                    });
    }
  }

  /** Close without focusing anything. */
  function cancel() // Dismiss overlay
  {
    close();
  }

  /** Reset all switcher state. */
  function close() // Internal reset
  {
    isOpen = false;
    items = [];
    selectedIndex = 0;
    safetyTimer.stop();
  }

  /** Snapshot live windows in most-recently-used order. */
  function buildItems() // Build MRU window list
  {
    var windows = [];
    for (var i = 0; i < CompositorService.windows.count; i++) {
      windows.push(CompositorService.windows.get(i));
    }

    var history = CompositorService.focusHistory;
    function rank(w) {
      var idx = history.indexOf(w.handle);
      // Windows never focused this session sort after remembered ones.
      return idx === -1 ? history.length + 1000 : idx;
    }
    windows.sort((a, b) => rank(a) - rank(b));

    var result = [];
    for (var j = 0; j < windows.length; j++) {
      var w = windows[j];
      var iconName = w.appId;
      var appEntry = ThemeIcons.findAppEntry(w.appId);
      if (appEntry && appEntry.icon) {
        iconName = appEntry.icon;
      }
      result.push({
                    "handle": w.handle,
                    "windowId": w.id,
                    "title": w.title || w.appId,
                    "appId": w.appId,
                    "icon": iconName || "application-x-executable",
                    "output": w.output,
                    "workspaceId": w.workspaceId,
                    "isFocused": w.isFocused
                  });
    }
    return result;
  }

  /** Resolve the screen hosting the currently focused window. */
  function focusedScreen() // Pick overlay target screen
  {
    var focused = CompositorService.getFocusedWindow();
    var name = focused ? focused.output : "";
    if (name) {
      for (var i = 0; i < Quickshell.screens.length; i++) {
        if (Quickshell.screens[i].name === name) {
          return Quickshell.screens[i];
        }
      }
    }
    return Quickshell.screens.length > 0 ? Quickshell.screens[0] : null;
  }
}
