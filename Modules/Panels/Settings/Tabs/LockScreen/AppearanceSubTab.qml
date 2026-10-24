// File: Modules/Panels/Settings/Tabs/LockScreen/AppearanceSubTab.qml
// =============================================================================
// Lock screen appearance settings. The lock screen uses the island look
// unconditionally, so the configured options revolve around it: the display
// clock layout, the album-art wash, cursor animations, and password dots.
//
// Functions:
//   (declarative component) - no imperative logic
// =============================================================================

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Widgets

ColumnLayout {
  id: root
  spacing: Style.marginL

  NToggle {
    Layout.fillWidth: true
    label: "Media on lock"
    description: "Wash the lock screen with the playing track's cover art."
    checked: Settings.data.islandLook.mediaOnLock
    onToggled: checked => Settings.data.islandLook.mediaOnLock = checked
  }

  NToggle {
    label: "Random password icons"
    description: "Cute icons used to hide your password."
    checked: Settings.data.general.passwordChars
    onToggled: checked => Settings.data.general.passwordChars = checked
    defaultValue: Settings.getDefaultValue("general.passwordChars")
  }

  NToggle {
    label: "Compact lock screen"
    description: "Slim readouts: smaller session buttons and a tighter status pill."
    checked: Settings.data.general.compactLockScreen
    onToggled: checked => Settings.data.general.compactLockScreen = checked
    defaultValue: Settings.getDefaultValue("general.compactLockScreen")
  }

  NToggle {
    label: "Lockscreen animations"
    description: "Enable or disable lockscreen animations."
    checked: Settings.data.general.lockScreenAnimations
    onToggled: checked => Settings.data.general.lockScreenAnimations = checked
    defaultValue: Settings.getDefaultValue("general.lockScreenAnimations")
  }
}
