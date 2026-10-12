import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Modules.Panels.Dashboard
import qs.Services.UI
import qs.Widgets

ColumnLayout {
  id: root
  spacing: Style.marginL
  Layout.fillWidth: true

  property var screen

  signal openMainFolderPicker
  signal openMonitorFolderPicker(string monitorName)

  NToggle {
    label: "Enable wallpaper management"
    description: "Manage wallpapers with Mordial. Uncheck if you prefer using another application."
    checked: Settings.data.wallpaper.enabled
    onToggled: checked => Settings.data.wallpaper.enabled = checked
    defaultValue: Settings.getDefaultValue("wallpaper.enabled")
  }

  ColumnLayout {
    enabled: Settings.data.wallpaper.enabled
    spacing: Style.marginL
    Layout.fillWidth: true

    RowLayout {

      NLabel {
        label: "Wallpaper selector"
        description: "Choose your wallpaper in the dashboard."
        Layout.alignment: Qt.AlignTop
      }

      NIconButton {
        icon: "wallpaper-selector"
        tooltipText: "Wallpaper selector"
        // The picker lives on the dashboard's wallpaper page, so the button
        // opens the dashboard there (and closes it if it is already showing).
        onClicked: DashboardPanelService.togglePage(DashboardPanel.Page.Wallpaper, root.screen, undefined)
      }
    }

    NComboBox {
      label: "Viewing mode"
      description: "Choose how wallpapers are displayed from your directory."
      Layout.fillWidth: true
      model: [
        {
          "key": "single",
          "name": "Root directory"
        },
        {
          "key": "recursive",
          "name": "Flattened subdirectories"
        },
        {
          "key": "browse",
          "name": "Browse directories"
        }
      ]
      currentKey: Settings.data.wallpaper.viewMode
      onSelected: key => Settings.data.wallpaper.viewMode = key
      defaultValue: Settings.getDefaultValue("wallpaper.viewMode")
    }

    NTextInputButton {
      id: wallpaperPathInput
      label: "Wallpaper folder"
      description: "Path to your main wallpaper folder."
      text: Settings.data.wallpaper.directory
      buttonIcon: "folder-open"
      buttonTooltip: "Wallpaper folder"
      Layout.fillWidth: true
      onInputTextChanged: text => Settings.data.wallpaper.directory = text
      onButtonClicked: root.openMainFolderPicker()
    }

    NToggle {
      label: "Monitor-specific directories"
      description: "Set a different wallpaper folder for each monitor."
      checked: Settings.data.wallpaper.enableMultiMonitorDirectories
      onToggled: checked => Settings.data.wallpaper.enableMultiMonitorDirectories = checked
      defaultValue: Settings.getDefaultValue("wallpaper.enableMultiMonitorDirectories")
    }

    NBox {
      visible: Settings.data.wallpaper.enableMultiMonitorDirectories
      Layout.fillWidth: true
      radius: Style.radiusM
      color: Color.mSurface
      border.color: Color.mOutline
      border.width: Style.borderS
      implicitHeight: contentCol.implicitHeight + Style.margin2L
      clip: true

      ColumnLayout {
        id: contentCol
        anchors.fill: parent
        anchors.margins: Style.marginL
        spacing: Style.marginM
        Repeater {
          model: Quickshell.screens || []
          delegate: ColumnLayout {
            Layout.fillWidth: true
            spacing: Style.marginS

            NText {
              text: (modelData.name || "Unknown")
              color: Color.mPrimary
              font.weight: Style.fontWeightBold
              pointSize: Style.fontSizeM
            }

            NTextInputButton {
              id: monitorDirInput
              text: WallpaperService.getMonitorDirectory(modelData.name)
              buttonIcon: "folder-open"
              buttonTooltip: "Monitor wallpaper folder"
              Layout.fillWidth: true
              onInputEditingFinished: WallpaperService.setMonitorDirectory(modelData.name, monitorDirInput.text)
              onButtonClicked: root.openMonitorFolderPicker(modelData.name)
            }
          }
        }
      }
    }
  }

  NDivider {
    Layout.fillWidth: true
  }

  NToggle {
    label: "Use original images"
    description: "Skip resizing wallpapers before display. Saves disk space and reduces CPU usage during wallpaper changes, but may use more memory for very large images."
    checked: Settings.data.wallpaper.useOriginalImages
    enabled: Settings.data.wallpaper.enabled
    onToggled: checked => Settings.data.wallpaper.useOriginalImages = checked
    defaultValue: Settings.getDefaultValue("wallpaper.useOriginalImages")
  }

  RowLayout {
    spacing: Style.marginM
    Layout.fillWidth: true
    enabled: Settings.data.wallpaper.enabled

    NLabel {
      label: "Wallpaper cache"
      description: "Clear cached resized wallpapers to free disk space."
      Layout.fillWidth: true
    }

    NButton {
      icon: "trash"
      text: "Clear cache"
      outlined: true
      onClicked: {
        ImageCacheService.clearLarge();
        ToastService.showNotice("Wallpaper cache cleared");
      }
    }
  }
}
