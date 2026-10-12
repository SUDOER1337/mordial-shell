import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Services.Control
import qs.Services.UI
import qs.Widgets

ColumnLayout {
  id: root
  enabled: Settings.data.hooks.enabled
  spacing: Style.marginL
  width: parent.width

  // Shared Edit Popup
  HookEditPopup {
    id: editPopup
    parent: Overlay.overlay
  }

  // Helper to open popup
  function openEdit(label, description, placeholder, value, onSave, onTest) {
    editPopup.hookLabel = label;
    editPopup.hookDescription = description;
    editPopup.hookPlaceholder = placeholder;
    editPopup.initialValue = value;

    // Disconnect previous signals
    try {
      editPopup.saved.disconnect(editPopup._savedSlot);
    } catch (e) {}
    try {
      editPopup.test.disconnect(editPopup._testSlot);
    } catch (e) {}

    // Define slots
    editPopup._savedSlot = onSave;
    editPopup._testSlot = onTest;

    // Connect new signals
    editPopup.saved.connect(editPopup._savedSlot);
    editPopup.test.connect(editPopup._testSlot);

    editPopup.open();
  }

  // Startup Hook
  HookRow {
    label: "Mordial started"
    description: "Command to execute when Mordial has finished loading."
    value: Settings.data.hooks.startup
    onEditClicked: openEdit(label, description, "e.g. notify-send 'Mordial Loaded'", value, newValue => {
                              Settings.data.hooks.startup = newValue;
                              Settings.saveImmediate();
                            }, val => {
                              HooksService.executeStartupHook();
                            })
  }

  // Wallpaper Hook
  HookRow {
    label: "Wallpaper changed"
    description: "Command to be executed when wallpaper changes."
    value: Settings.data.hooks.wallpaperChange
    onEditClicked: openEdit(label, description, "e.g. notify-send \"Wallpaper\" \"Changed\"", value, newValue => {
                              Settings.data.hooks.wallpaperChange = newValue;
                              Settings.saveImmediate();
                            }, val => {
                              if (val)
                              Quickshell.execDetached(["sh", "-lc", val.replace("$1", "test_wallpaper_path").replace("$2", "test_screen").replace("$3", "dark")]);
                            })
  }

  // Color Generation Hook
  HookRow {
    label: "Colors generated"
    description: "Command to be executed when color generation completes (e.g. after wallpaper-based theming)."
    value: Settings.data.hooks.colorGeneration
    onEditClicked: openEdit(label, description, "e.g. notify-send \"Colors\" \"Generated\"", value, newValue => {
                              Settings.data.hooks.colorGeneration = newValue;
                              Settings.saveImmediate();
                            }, val => {
                              if (val)
                              Quickshell.execDetached(["sh", "-lc", val.replace("$1", "dark")]);
                            })
  }

  // Theme Hook
  HookRow {
    label: "Theme changed"
    description: "Command to be executed when theme toggles between Dark and Light Mode."
    value: Settings.data.hooks.darkModeChange
    onEditClicked: openEdit(label, description, "e.g. notify-send \"Theme\" \"Toggled\"", value, newValue => {
                              Settings.data.hooks.darkModeChange = newValue;
                              Settings.saveImmediate();
                            }, val => {
                              if (val)
                              Quickshell.execDetached(["sh", "-lc", val.replace("$1", "true")]);
                            })
  }

  // Screen Lock Hook
  HookRow {
    label: "Screen locked"
    description: "Command to be executed when the screen is locked."
    value: Settings.data.hooks.screenLock
    onEditClicked: openEdit(label, description, "e.g. notify-send \"Screen\" \"Locked\"", value, newValue => {
                              Settings.data.hooks.screenLock = newValue;
                              Settings.saveImmediate();
                            }, val => {
                              if (val)
                              Quickshell.execDetached(["sh", "-lc", val]);
                            })
  }

  // Screen Unlock Hook
  HookRow {
    label: "Screen unlocked"
    description: "Command to be executed when the lock screen is unlocked."
    value: Settings.data.hooks.screenUnlock
    onEditClicked: openEdit(label, description, "e.g. notify-send \"Screen\" \"Unlocked\"", value, newValue => {
                              Settings.data.hooks.screenUnlock = newValue;
                              Settings.saveImmediate();
                            }, val => {
                              if (val)
                              Quickshell.execDetached(["sh", "-lc", val]);
                            })
  }

  // Session Hook
  HookRow {
    label: "Session end"
    description: "Command to be executed before shutdown or reboot. Receives action type as $1 (shutdown/reboot)."
    value: Settings.data.hooks.session
    onEditClicked: openEdit(label, description, "e.g. notify-send \"Session\" \"$1\"", value, newValue => {
                              Settings.data.hooks.session = newValue;
                              Settings.saveImmediate();
                            }, val => {
                              if (val)
                              Quickshell.execDetached(["sh", "-lc", val + " test"]);
                            })
  }
}
