import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Services.System
import qs.Services.Theming
import qs.Services.UI
import qs.Widgets

ColumnLayout {
  id: root
  spacing: Style.marginL
  Layout.fillWidth: true

  property var timeOptions
  property var schemeColorsCache: ({})
  property int cacheVersion: 0
  property var screen

  signal openDownloadPopup

  function extractSchemeName(schemePath) {
    var pathParts = schemePath.split("/");
    var filename = pathParts[pathParts.length - 1];
    var schemeName = filename.replace(".json", "");

    if (schemeName === "Mordial-default") {
      schemeName = "Mordial (default)";
    } else if (schemeName === "Mordial-legacy") {
      schemeName = "Mordial (legacy)";
    } else if (schemeName === "Tokyo-Night") {
      schemeName = "Tokyo Night";
    } else if (schemeName === "Rosepine") {
      schemeName = "Rose Pine";
    }

    return schemeName;
  }

  /** Look up a color token from a cached scheme, falling back to the
  *  active Color singleton value. Supports all 30 MD3 tokens.
  *  @param schemeName - Display name of the scheme
  *  @param colorKey - Token name like "mPrimary" or "mPrimaryContainer"
  *  @returns The resolved color (falls through to Color.* for live values) */
  function getSchemeColor(schemeName, colorKey) // Resolve a scheme color token
  {
    var _ = cacheVersion;

    if (schemeColorsCache[schemeName]) {
      var entry = schemeColorsCache[schemeName];
      var variant = entry;

      if (entry.dark || entry.light) {
        variant = Settings.data.colorSchemes.darkMode ? (entry.dark || entry.light) : (entry.light || entry.dark);
      }

      if (variant && variant[colorKey]) {
        return variant[colorKey];
      }
    }

    // Fallback: use the live color from the current theme
    // Safety check: if the token exists on Color, use it; otherwise compute
    if (colorKey in Color)
      return Color[colorKey];

    // Container fallbacks: derive from base accent
    var isDark = Settings.data.colorSchemes.darkMode;
    if (colorKey === "mPrimaryContainer" || colorKey === "mSecondaryContainer" || colorKey === "mTertiaryContainer" || colorKey === "mErrorContainer") {
      var baseKey = "m" + colorKey.charAt(1).toUpperCase() + colorKey.slice(2).replace("Container", "");
      if (baseKey in Color)
        return ColorSaturation.generateContainerColor(Color[baseKey], isDark);
    }
    if (colorKey.replace("Container", "") !== colorKey) {
      var onKey = "mOn" + colorKey.charAt(1).toUpperCase() + colorKey.slice(2);
      if (onKey in Color)
        return Color[onKey];
    }
    if (colorKey === "mBackground")
      return Color.mSurface;
    if (colorKey === "mOnBackground")
      return Color.mOnSurface;
    if (colorKey === "mSurfaceContainerLow")
      return ColorSaturation.generateSurfaceVariant(Color.mSurface, 1, isDark);
    if (colorKey === "mSurfaceContainer")
      return Color.mSurfaceVariant;
    if (colorKey === "mSurfaceContainerHigh")
      return ColorSaturation.generateSurfaceVariant(Color.mSurface, 3, isDark);
    if (colorKey === "mOutlineVariant")
      return ColorSaturation.adjustLightnessAndSaturation(Color.mOutline, isDark ? 10 : -10, isDark ? -10 : 10);
    return Color.mOnSurfaceVariant;
  }

  function schemeLoaded(schemeName, jsonData) {
    var value = jsonData || {};
    schemeColorsCache[schemeName] = value;
    cacheVersion++;
  }

  Connections {
    target: ColorSchemeService
    function onSchemesChanged() {
      root.schemeColorsCache = {};
      root.cacheVersion++;
    }
  }

  Item {
    id: fileLoaders
    visible: false

    Repeater {
      model: ColorSchemeService.schemes
      delegate: Item {
        FileView {
          path: modelData
          blockLoading: false
          onLoaded: {
            var schemeName = root.extractSchemeName(path);

            try {
              var jsonData = JSON.parse(text());
              root.schemeLoaded(schemeName, jsonData);
            } catch (e) {
              Logger.w("ColorSchemeTab", "Failed to parse JSON for scheme:", schemeName, e);
              root.schemeLoaded(schemeName, null);
            }
          }
        }
      }
    }
  }

  NToggle {
    label: "Dark Mode"
    description: "Switches to a darker theme for easier viewing at night."
    checked: Settings.data.colorSchemes.darkMode
    onToggled: checked => {
                 Settings.data.colorSchemes.darkMode = checked;
                 root.cacheVersion++;
               }
  }

  NToggle {
    label: "Sync system theme"
    description: "Match the system theme to the active light or dark variant."
    checked: Settings.data.colorSchemes.syncGsettings
    defaultValue: Settings.getDefaultValue("colorSchemes.syncGsettings")
    onToggled: checked => {
                 Settings.data.colorSchemes.syncGsettings = checked;
                 if (checked)
                 ColorSchemeService.pushSystemColorScheme();
               }
  }

  NComboBox {
    label: "Dark Mode schedule"
    description: "Enables automatic switching between Light and Dark Mode."

    model: [
      {
        "name": "Off",
        "key": "off"
      },
      {
        "name": "Manual",
        "key": "manual"
      },
      {
        "name": "Location",
        "key": "location"
      }
    ]

    currentKey: Settings.data.colorSchemes.schedulingMode
    defaultValue: Settings.getDefaultValue("colorSchemes.schedulingMode")

    onSelected: key => {
                  Settings.data.colorSchemes.schedulingMode = key;
                  AppThemeService.generate();
                }
  }

  ColumnLayout {
    spacing: Style.marginS
    visible: Settings.data.colorSchemes.schedulingMode === "manual"

    NLabel {
      label: "Manual scheduling"
      description: "Set custom times for sunrise and sunset."
    }

    RowLayout {
      Layout.fillWidth: false
      spacing: Style.marginS

      NText {
        text: "Sunrise time"
        pointSize: Style.fontSizeM
        color: Color.mOnSurfaceVariant
      }

      NComboBox {
        model: root.timeOptions
        currentKey: Settings.data.colorSchemes.manualSunrise
        placeholder: "Select start time"
        onSelected: key => Settings.data.colorSchemes.manualSunrise = key
        minimumWidth: 120
      }

      Item {
        Layout.preferredWidth: 20
      }

      NText {
        text: "Sunset time"
        pointSize: Style.fontSizeM
        color: Color.mOnSurfaceVariant
      }

      NComboBox {
        model: root.timeOptions
        currentKey: Settings.data.colorSchemes.manualSunset
        placeholder: "Select stop time"
        onSelected: key => Settings.data.colorSchemes.manualSunset = key
        minimumWidth: 120
      }
    }
  }

  NDivider {
    Layout.fillWidth: true
  }

  NToggle {
    label: "Use wallpaper colors"
    description: "Generate color schemes from your wallpaper. Automatically extracts colors to create a cohesive theme."
    checked: Settings.data.colorSchemes.useWallpaperColors
    defaultValue: Settings.getDefaultValue("colorSchemes.useWallpaperColors")
    onToggled: checked => {
                 Settings.data.colorSchemes.useWallpaperColors = checked;
                 if (checked) {
                   AppThemeService.generate();
                 } else {
                   ToastService.showNotice("Wallpaper colors", "Wallpaper colors disabled", "settings-color-scheme");
                   if (Settings.data.colorSchemes.predefinedScheme) {
                     ColorSchemeService.applyScheme(Settings.data.colorSchemes.predefinedScheme);
                   }
                 }
               }
  }

  NComboBox {
    Layout.fillWidth: true
    label: "Color generation source"
    description: "Select which monitor to use for extracting wallpaper colors."
    enabled: Settings.data.colorSchemes.useWallpaperColors
    model: {
      var m = [];
      if (Quickshell.screens) {
        for (var i = 0; i < Quickshell.screens.length; i++) {
          var screen = Quickshell.screens[i];
          var name = screen.name;
          var displayName = name + " (" + screen.width + "x" + screen.height + ")";
          m.push({
                   "key": name,
                   "name": displayName
                 });
        }
      }
      return m;
    }
    currentKey: Settings.data.colorSchemes.monitorForColors || (screen ? screen.name : "")
    onSelected: key => {
                  Settings.data.colorSchemes.monitorForColors = key;
                  AppThemeService.generate();
                }
  }

  NComboBox {
    Layout.fillWidth: true
    label: "Palette generation method"
    description: "Choose your favorite palette generation method."
    enabled: Settings.data.colorSchemes.useWallpaperColors
    model: TemplateProcessor.schemeTypes
    currentKey: Settings.data.colorSchemes.generationMethod
    onSelected: key => {
                  Settings.data.colorSchemes.generationMethod = key;
                  AppThemeService.generate();
                }
  }

  NBox {
    visible: Settings.data.colorSchemes.useWallpaperColors
    Layout.fillWidth: true
    implicitHeight: descriptionColumn.implicitHeight + Style.margin2L
    containerLevel: 1

    Column {
      id: descriptionColumn
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.top: parent.top
      anchors.margins: Style.marginL
      spacing: Style.marginM

      NText {
        width: parent.width
        wrapMode: Text.WordWrap
        text: I18n.tr("panels.color-scheme.method-description." + Settings.data.colorSchemes.generationMethod)
        pointSize: Style.fontSizeS
        color: Color.mOnSurfaceVariant
      }

      Row {
        id: colorPreviewRow
        spacing: Style.marginS

        property int diameter: 16 * Style.uiScaleRatio

        Repeater {
          model: [Color.mPrimary, Color.mSecondary, Color.mTertiary, Color.mError]

          Rectangle {
            width: colorPreviewRow.diameter
            height: colorPreviewRow.diameter
            radius: width * 0.5
            color: modelData
          }
        }
      }
    }
  }

  NDivider {
    Layout.fillWidth: true
  }

  ColumnLayout {
    spacing: Style.marginM
    Layout.fillWidth: true
    enabled: !Settings.data.colorSchemes.useWallpaperColors

    NHeader {
      label: "Predefined color schemes"
      description: "Choose from a collection of predefined color schemes."
      Layout.fillWidth: true
    }

    GridLayout {
      columns: 2
      rowSpacing: Style.marginM
      columnSpacing: Style.marginM
      Layout.fillWidth: true

      Repeater {
        model: ColorSchemeService.schemes

        Rectangle {
          id: schemeItem

          property string schemePath: modelData
          property string schemeName: root.extractSchemeName(modelData)

          opacity: enabled ? 1.0 : 0.6
          Layout.fillWidth: true
          Layout.alignment: Qt.AlignHCenter
          height: 64 * Style.uiScaleRatio
          radius: Style.radiusS
          color: root.getSchemeColor(schemeName, "mSurface")
          border.width: Style.borderL
          border.color: {
            if ((Settings.data.colorSchemes.predefinedScheme === schemeName) && schemeItem.enabled) {
              return Color.mSecondary;
            }
            if (itemMouseArea.containsMouse) {
              return Color.mHover;
            }
            return Color.mOutline;
          }

          Column {
            anchors.fill: parent
            anchors.margins: Style.marginL
            spacing: 2

            RowLayout {
              width: parent.width
              spacing: Style.marginS

              NText {
                text: schemeItem.schemeName
                pointSize: Style.fontSizeS
                color: Color.mOnSurface
                Layout.fillWidth: true
                elide: Text.ElideRight
                verticalAlignment: Text.AlignVCenter
                wrapMode: Text.WordWrap
                maximumLineCount: 1
              }

              readonly property int diameter: 14 * Style.uiScaleRatio

              Rectangle {
                width: parent.diameter
                height: parent.diameter
                radius: parent.diameter * 0.5
                color: root.getSchemeColor(schemeItem.schemeName, "mPrimary")
              }

              Rectangle {
                width: parent.diameter
                height: parent.diameter
                radius: parent.diameter * 0.5
                color: root.getSchemeColor(schemeItem.schemeName, "mSecondary")
              }

              Rectangle {
                width: parent.diameter
                height: parent.diameter
                radius: parent.diameter * 0.5
                color: root.getSchemeColor(schemeItem.schemeName, "mTertiary")
              }

              Rectangle {
                width: parent.diameter
                height: parent.diameter
                radius: parent.diameter * 0.5
                color: root.getSchemeColor(schemeItem.schemeName, "mError")
              }
            }

            RowLayout {
              width: parent.width
              spacing: Style.marginS
              // Container swatches — same width as first row items, right-aligned
              Item {
                Layout.fillWidth: true
              } // spacer matching text area

              readonly property int diameter: 10 * Style.uiScaleRatio

              Rectangle {
                width: parent.diameter
                height: parent.diameter
                radius: parent.diameter * 0.5
                border.width: 1
                border.color: Color.mOutlineVariant
                color: root.getSchemeColor(schemeItem.schemeName, "mPrimaryContainer")
              }

              Rectangle {
                width: parent.diameter
                height: parent.diameter
                radius: parent.diameter * 0.5
                border.width: 1
                border.color: Color.mOutlineVariant
                color: root.getSchemeColor(schemeItem.schemeName, "mSecondaryContainer")
              }

              Rectangle {
                width: parent.diameter
                height: parent.diameter
                radius: parent.diameter * 0.5
                border.width: 1
                border.color: Color.mOutlineVariant
                color: root.getSchemeColor(schemeItem.schemeName, "mTertiaryContainer")
              }

              Rectangle {
                width: parent.diameter
                height: parent.diameter
                radius: parent.diameter * 0.5
                border.width: 1
                border.color: Color.mOutlineVariant
                color: root.getSchemeColor(schemeItem.schemeName, "mErrorContainer")
              }
            }
          }

          MouseArea {
            id: itemMouseArea
            anchors.fill: parent
            enabled: schemeItem.enabled
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
              Settings.data.colorSchemes.useWallpaperColors = false;
              Logger.i("ColorSchemeTab", "Disabled wallpaper colors");

              Settings.data.colorSchemes.predefinedScheme = schemeItem.schemeName;
              ColorSchemeService.applyScheme(Settings.data.colorSchemes.predefinedScheme);
            }
          }

          Rectangle {
            visible: (Settings.data.colorSchemes.predefinedScheme === schemeItem.schemeName) && schemeItem.enabled
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.rightMargin: 0
            anchors.topMargin: -3
            width: 20
            height: 20
            radius: Math.min(Style.radiusL, width / 2)
            color: Color.mSecondary
            border.width: Style.borderS
            border.color: Color.mOnSecondary

            NIcon {
              icon: "check"
              pointSize: Style.fontSizeXS
              color: Color.mOnSecondary
              anchors.centerIn: parent
            }
          }

          Behavior on border.color {
            ColorAnimation {
              duration: Style.animationNormal
            }
          }
        }
      }
    }

    NButton {
      text: "Download more"
      icon: "download"
      onClicked: root.openDownloadPopup()
      Layout.alignment: Qt.AlignRight
      Layout.topMargin: Style.marginS
    }
  }
}
