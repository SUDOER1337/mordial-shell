pragma Singleton

import QtQuick
import Quickshell
import qs.Commons
import qs.Modules.Tooltip

Singleton {
  id: root

  property var activeTooltip: null
  property var pendingTooltip: null // Track tooltip being created

  // A tooltip is a PopupWindow, i.e. its own surface. Reading one takes the
  // pointer out of the panel that spawned it, so hover-opened panels consult
  // this to treat a visible tooltip as continued pointer presence instead of
  // closing under the cursor. This replaces suppressing tooltips outright,
  // which left a hover-opened Dashboard with no labels and no tooltips.
  readonly property bool hasVisibleTooltip: activeTooltip !== null

  // Tooltip windows sit outside the QML item tree of their source. Panels use
  // this ownership check instead of the global visibility flag so a tooltip in
  // one panel cannot keep an unrelated hover-opened panel alive.
  function hasVisibleTooltipFor(ancestor) {
    if (!activeTooltip || !activeTooltip.targetItem || !ancestor)
      return false;

    let item = activeTooltip.targetItem;
    while (item) {
      if (item === ancestor)
        return true;
      item = item.parent;
    }
    return false;
  }

  property Component tooltipComponent: Component {
    Tooltip {}
  }

  function show(target, content, direction, delay, fontFamily) {
    if (!Settings.data.ui.tooltipsEnabled) {
      return;
    }

    // Don't create if no content
    if (!target || !content || (Array.isArray(content) && content.length === 0)) {
      Logger.i("Tooltip", "No target or content");
      return;
    }

    // Cancel any pending tooltip (same or different target)
    if (pendingTooltip) {
      pendingTooltip.hideImmediately();
      pendingTooltip.destroy();
      pendingTooltip = null;
    }

    // If we have an active tooltip for a different target, hide it
    if (activeTooltip && activeTooltip.targetItem !== target) {
      activeTooltip.hideImmediately();
      // Don't destroy immediately - let it clean itself up
      activeTooltip = null;
    }

    // If we already have a tooltip for this target, just update it
    if (activeTooltip && activeTooltip.targetItem === target) {
      activeTooltip.cancelPendingHide();
      activeTooltip.updateContent(content);
      return activeTooltip;
    }

    // Create new tooltip instance
    const newTooltip = tooltipComponent.createObject(null);

    if (newTooltip) {
      // Track as pending until it's visible
      pendingTooltip = newTooltip;

      // Connect cleanup when tooltip hides
      newTooltip.visibleChanged.connect(() => {
                                          if (!newTooltip.visible) {
                                            // Clean up after a delay to avoid interfering with new tooltips
                                            Qt.callLater(() => {
                                                           if (newTooltip && !newTooltip.visible) {
                                                             if (activeTooltip === newTooltip) {
                                                               activeTooltip = null;
                                                             }
                                                             if (pendingTooltip === newTooltip) {
                                                               pendingTooltip = null;
                                                             }
                                                             newTooltip.destroy();
                                                           }
                                                         });
                                          } else {
                                            // Tooltip is now visible, move from pending to active
                                            if (pendingTooltip === newTooltip) {
                                              activeTooltip = newTooltip;
                                              pendingTooltip = null;
                                            }
                                          }
                                        });

      // Show the tooltip
      newTooltip.show(target, content, direction || "auto", delay || Style.tooltipDelay, fontFamily);

      return newTooltip;
    } else {
      Logger.e("Tooltip", "Failed to create tooltip instance");
    }

    return null;
  }

  function hide(target) {
    // If target is provided, only hide if tooltip belongs to that target
    if (target) {
      if (pendingTooltip && pendingTooltip.targetItem === target) {
        pendingTooltip.hide();
      }
      if (activeTooltip && activeTooltip.targetItem === target) {
        activeTooltip.hide();
      }
    } else {
      if (pendingTooltip) {
        pendingTooltip.hide();
      }
      if (activeTooltip) {
        activeTooltip.hide();
      }
    }
  }

  function hideImmediately() {
    if (pendingTooltip) {
      pendingTooltip.hideImmediately();
      pendingTooltip.destroy();
      pendingTooltip = null;
    }
    if (activeTooltip) {
      activeTooltip.hideImmediately();
      activeTooltip.destroy();
      activeTooltip = null;
    }
  }

  function updateContent(newContent) {
    if (activeTooltip) {
      activeTooltip.updateContent(newContent);
    }
  }

  // Backward compatibility alias
  function updateText(newText) {
    updateContent(newText);
  }
}
