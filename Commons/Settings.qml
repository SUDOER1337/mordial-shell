// File: Commons/Settings.qml
// =============================================================================
// Central settings singleton — persists shell configuration to settings.json,
// provides the typed adapter tree (Settings.data.*), handles directory creation,
// settings version migration, per-screen bar overrides, and external file-watch
// reload with debouncing.
//
// Functions:
//   saveImmediate()              - Write current settings to disk immediately
//   scheduleExternalReload()     - Debounced reload from file watcher
//   preprocessPath(path)         - Expand ~ and resolve relative paths
//   getBarPositionForScreen(n)   - Get bar position override for a screen
//   setScreenOverride(n, p, v)  - Set a per-screen override property
//   clearScreenOverride(n, p)    - Remove per-screen override(s)
//   migrateRawSettings(raw)      - One-shot key renames on the raw JSON (pre-adapter)
//   upgradeSettings()            - Migrate old settings to current version
//   generateDefaultSettings()    - Write factory defaults (debug mode)
//
// Properties:
//   data                         - Alias to the typed settings adapter tree
//   settingsVersion              - Schema version for migration tracking
//   configDir / cacheDir         - Resolved config and cache directories
//   isDebug                      - True when MORDIAL_DEBUG=1
//   isLoaded                     - True after first successful load
// =============================================================================

pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "../Helpers/QtObj2JS.js" as QtObj2JS
import qs.Commons
import qs.Modules.OSD
import qs.Services.UI

Singleton {
  id: root

  property bool isLoaded: false
  property bool reloadSettings: false
  property bool directoriesCreated: false
  property bool isFreshInstall: false

  /*
  Shell directories.
  - Default config directory: ~/.config/mordial
  - Default cache directory: ~/.cache/mordial
  */
  readonly property alias data: adapter  // Used to access via Settings.data.xxx.yyy
  readonly property int settingsVersion: 60
  property bool isDebug: Quickshell.env("MORDIAL_DEBUG") === "1"
  readonly property string shellName: "mordial"
  readonly property string configDir: ensureTrailingSlash(Quickshell.env("MORDIAL_CONFIG_DIR") || (Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config") + "/" + shellName + "/")
  readonly property string cacheDir: ensureTrailingSlash(Quickshell.env("MORDIAL_CACHE_DIR") || (Quickshell.env("XDG_CACHE_HOME") || Quickshell.env("HOME") + "/.cache") + "/" + shellName + "/")

  readonly property string settingsFile: Quickshell.env("MORDIAL_SETTINGS_FILE") || (configDir + "settings.json")
  readonly property string defaultVideosDirectory: Quickshell.env("HOME") + "/Videos"
  readonly property string defaultWallpapersDirectory: Quickshell.env("HOME") + "/Pictures/Wallpapers"

  signal settingsLoaded
  signal settingsSaved
  signal settingsReloaded

  // Debounce external reload requests (file watcher + directory watcher)
  // so atomic replacements only trigger one reload.
  Timer {
    id: externalReloadTimer
    running: false
    interval: 200
    onTriggered: {
      if (settingsFileView.path !== undefined) {
        Logger.d("Settings", "Reloading settings after external change detection");
        reloadSettings = true;
        settingsFileView.reload();
      }
    }
  }

  function scheduleExternalReload() {
    if (!directoriesCreated || settingsFileView.path === undefined) {
      return;
    }
    externalReloadTimer.restart();
  }

  // -----------------------------------------------------
  // -----------------------------------------------------
  // Ensure directories exist before FileView tries to read files
  Component.onCompleted: {
    // ensure settings dir exists
    Quickshell.execDetached(["mkdir", "-p", configDir]);
    Quickshell.execDetached(["mkdir", "-p", cacheDir]);

    // Mark directories as created and trigger file loading
    directoriesCreated = true;

    // This should only be activated once when the settings structure has changed
    // Then it should be commented out again, regular users don't need to generate
    // default settings on every start
    if (isDebug) {
      generateDefaultSettings();
      generateWidgetDefaultSettings();
    }

    // Patch-in the local default, resolved to user's home
    adapter.wallpaper.directory = defaultWallpapersDirectory;
    adapter.ui.fontDefault = Qt.application.font.family;
    adapter.ui.fontFixed = "monospace";

    // Set the adapter to the settingsFileView to trigger the real settings load
    settingsFileView.adapter = adapter;
  }

  // Don't write settings to disk immediately
  // This avoid excessive IO when a variable changes rapidly (ex: sliders)
  Timer {
    id: saveTimer
    running: false
    interval: 500
    onTriggered: {
      root.saveImmediate();
    }
  }

  FileView {
    id: settingsFileView
    path: directoriesCreated ? settingsFile : undefined
    printErrors: false
    watchChanges: true
    onAdapterUpdated: saveTimer.start()

    onFileChanged: scheduleExternalReload()

    // Trigger initial load when path changes from empty to actual path
    onPathChanged: {
      if (path !== undefined) {
        reload();
      }
    }
    onLoaded: function () {
      if (!isLoaded) {
        Logger.i("Settings", "Settings loaded");

        // Load raw JSON for migrations (adapter doesn't expose removed properties)
        var rawJson = null;
        try {
          rawJson = JSON.parse(settingsFileView.text());
        } catch (e) {
          Logger.w("Settings", "Could not parse raw JSON for migrations");
        }

        migrateRawSettings(rawJson);

        // Finally, update our local settings version
        adapter.settingsVersion = settingsVersion;

        // Emit the signal
        root.isLoaded = true;
        root.settingsLoaded();

        upgradeSettings();
      } else {
        Logger.d("Settings", "Settings reloaded from external file change");
        root.settingsReloaded();
      }
    }
    onLoadFailed: function (error) {
      if (reloadSettings) {
        reloadSettings = false;
        return;
      }
      if (error.toString().includes("No such file") || error === 2) {
        // File doesn't exist, create it with default values
        root.isFreshInstall = true;
        writeAdapter();
      }
    }
  }

  // Watch parent config directory as a fallback for declarative setups where
  // settings.json may be replaced atomically (e.g., symlink/store-path swap).
  FileView {
    id: settingsDirWatcher
    path: directoriesCreated ? configDir : undefined
    printErrors: false
    watchChanges: true
    onFileChanged: scheduleExternalReload()
  }

  // FileView to load default settings for comparison
  FileView {
    id: defaultSettingsFileView
    path: Quickshell.shellDir + "/Assets/settings-default.json"
    printErrors: false
    watchChanges: false
  }

  // Cached default settings object
  property var _defaultSettings: null

  // Load default settings when file is loaded
  Connections {
    target: defaultSettingsFileView
    function onLoaded() {
      try {
        root._defaultSettings = JSON.parse(defaultSettingsFileView.text());
      } catch (e) {
        Logger.w("Settings", "Failed to parse default settings file: " + e);
        root._defaultSettings = null;
      }
    }
  }

  JsonAdapter {
    id: adapter

    property int settingsVersion: 0

    // bar
    property JsonObject bar: JsonObject {
      property string barType: "simple" // "simple", "floating", "framed"
      property string position: "top" // "top", "bottom", "left", or "right"
      property list<string> monitors: [] // holds bar visibility per monitor
      property string density: "default" // "compact", "default", "comfortable"
      property bool showOutline: false
      property real outlineOpacity: 1.0
      property string outlineColorKey: "primary"
      property bool showCapsule: true
      property real capsuleOpacity: 1.0
      property string capsuleColorKey: "none"
      property int widgetSpacing: 6
      property int contentPadding: 2
      property real fontScale: 1.0
      property bool enableExclusionZoneInset: true

      // Bar background opacity settings
      property real backgroundOpacity: 0.93
      property bool useSeparateOpacity: false

      // Floating bar settings
      property int marginVertical: 4
      property int marginHorizontal: 4

      // Framed bar settings
      property int frameThickness: 8
      property int frameRadius: 12

      // Bar outer corners (inverted/concave corners at bar edges when not floating)
      property bool outerCorners: true

      // Hide bar/panels when compositor overview is active
      property bool hideOnOverview: false

      // Auto-hide settings
      property string displayMode: "always_visible"
      property int autoHideDelay: 500 // ms before hiding after mouse leaves
      property int autoShowDelay: 150 // ms before showing when mouse enters
      property bool showOnWorkspaceSwitch: true // show bar briefly on workspace switch

      // Open a bar widget's panel by hovering it instead of clicking
      property bool hoverOpenPanels: false
      property int hoverOpenDelay: 400 // ms the pointer must rest on a widget
      property int hoverCloseDelay: 250 // ms grace period to reach the panel

      // Widget configuration for modular bar system
      property JsonObject widgets
      widgets: JsonObject {
        property list<var> left: [
          {
            "id": "Launcher"
          },
          {
            "id": "Clock"
          },
          {
            "id": "SystemMonitor"
          },
          {
            "id": "ActiveWindow"
          },
          {
            "id": "MediaMini"
          }
        ]
        property list<var> center: [
          {
            "id": "Workspace"
          }
        ]
        property list<var> right: [
          {
            "id": "Tray"
          },
          {
            "id": "NotificationHistory"
          },
          {
            "id": "Battery"
          },
          {
            "id": "Volume"
          },
          {
            "id": "Brightness"
          },
          {
            "id": "Dashboard"
          }
        ]
      }
      property string mouseWheelAction: "none"
      property bool reverseScroll: false
      property bool mouseWheelWrap: true
      property string middleClickAction: "none"
      property bool middleClickFollowMouse: false
      property string middleClickCommand: ""
      property string rightClickAction: "dashboard"
      property bool rightClickFollowMouse: true
      property string rightClickCommand: ""
      // Per-screen overrides for position and widgets
      // Format: [{ "name": "HDMI-1", "position": "left" }, { "name": "DP-1", "position": "bottom", "widgets": {...} }]
      property list<var> screenOverrides: []
    }

    // general
    property JsonObject general: JsonObject {
      property real dimmerOpacity: 0.2
      property bool showScreenCorners: false
      property bool forceBlackScreenCorners: false
      property real scaleRatio: 1.0
      property real radiusRatio: 1.0
      property real iRadiusRatio: 1.0
      property real boxRadiusRatio: 1.0
      property real screenRadiusRatio: 1.0
      property real animationSpeed: 1.0
      property bool animationDisabled: false
      property bool compactLockScreen: false
      property bool lockScreenAnimations: false
      property bool lockOnSuspend: true
      property bool showSessionButtonsOnLockScreen: true
      property bool showHibernateOnLockScreen: false
      property bool enableLockScreenMediaControls: false
      property bool enableShadows: true
      property bool enableBlurBehind: true
      property string shadowDirection: "bottom_right"
      property int shadowOffsetX: 2
      property int shadowOffsetY: 3
      property string language: ""
      property bool allowPanelsOnScreenWithoutBar: true
      property bool telemetryEnabled: false
      property bool enableLockScreenCountdown: true
      property int lockScreenCountdownDuration: 10000
      property bool autoStartAuth: false
      property bool allowPasswordWithFprintd: false
      property string clockStyle: "custom"
      property string clockFormat: "hh\\nmm"
      property bool passwordChars: false
      property list<string> lockScreenMonitors: [] // holds lock screen visibility per monitor
      property real lockScreenBlur: 0.0
      property real lockScreenTint: 0.0
      property JsonObject keybinds: JsonObject {
        property list<string> keyUp: ["Up"]
        property list<string> keyDown: ["Down"]
        property list<string> keyLeft: ["Left"]
        property list<string> keyRight: ["Right"]
        property list<string> keyEnter: ["Return", "Enter"]
        property list<string> keyEscape: ["Esc"]
        property list<string> keyRemove: ["Del"]
      }
      property bool reverseScroll: false
      property bool smoothScrollEnabled: true
    }

    // ui
    property JsonObject ui: JsonObject {
      property string fontDefault: ""
      property string fontFixed: ""
      property real fontDefaultScale: 1.0
      property real fontFixedScale: 1.0
      property bool tooltipsEnabled: true
      property bool scrollbarAlwaysVisible: true
      property bool boxBorderEnabled: false
      property real panelBackgroundOpacity: 0.93
      property bool translucentWidgets: false
      property bool panelsAttachedToBar: true
      property string settingsPanelMode: "attached" // "centered", "attached", "window"
      property bool settingsPanelSideBarCardStyle: false
    }

    // location
    property JsonObject location: JsonObject {
      property string name: ""
      property bool weatherEnabled: true
      property bool weatherShowEffects: true
      property bool weatherTaliaMascotAlways: false
      property bool useFahrenheit: false
      property bool use12hourFormat: false
      property bool showWeekNumberInCalendar: false
      property bool showCalendarEvents: true
      property bool showCalendarWeather: true
      property bool analogClockInCalendar: false
      property int firstDayOfWeek: -1 // -1 = auto (use locale), 0 = Sunday, 1 = Monday, 6 = Saturday
      property bool hideWeatherTimezone: false
      property bool hideWeatherCityName: false
      property bool autoLocate: false
    }

    // calendar
    property JsonObject calendar: JsonObject {
      property list<var> cards: [
        {
          "id": "calendar-header-card",
          "enabled": true
        },
        {
          "id": "calendar-month-card",
          "enabled": true
        },
        {
          "id": "weather-card",
          "enabled": true
        }
      ]
    }

    // wallpaper
    property JsonObject wallpaper: JsonObject {
      property bool enabled: true
      property bool overviewEnabled: false
      property string directory: ""
      property list<var> monitorDirectories: []
      property bool enableMultiMonitorDirectories: false
      property bool showHiddenFiles: false
      property string viewMode: "single" // "single" | "recursive" | "browse"
      property bool setWallpaperOnAllMonitors: true
      property bool linkLightAndDarkWallpapers: true
      property string fillMode: "crop"
      property color fillColor: "#000000"
      property bool useSolidColor: false
      property color solidColor: "#1a1a2e"
      property bool automationEnabled: false
      property string wallpaperChangeMode: "random" // "random" or "alphabetical"
      property int randomIntervalSec: 300 // 5 min
      property int transitionDuration: 1500 // 1500 ms
      property list<string> transitionType: ["fade", "disc", "stripes", "wipe", "pixelate", "honeycomb"]
      property bool skipStartupTransition: false
      property real transitionEdgeSmoothness: 0.05
      property bool hideWallpaperFilenames: false
      property bool useOriginalImages: false
      property real overviewBlur: 0.4
      property real overviewTint: 0.6
      // Wallhaven settings
      property bool useWallhaven: false
      property string wallhavenQuery: ""
      property string wallhavenSorting: "relevance"
      property string wallhavenOrder: "desc"
      property string wallhavenCategories: "111" // general,anime,people
      property string wallhavenPurity: "100" // sfw only
      property string wallhavenRatios: ""
      property string wallhavenApiKey: ""
      property string wallhavenResolutionMode: "atleast" // "atleast" or "exact"
      property string wallhavenResolutionWidth: ""

      property string wallhavenResolutionHeight: ""
      property string sortOrder: "name" // "name", "name_desc", "date", "date_desc", "random"
      property list<var> favorites: []
      // Format: [{ "path": "...", "appearance": "light"|"dark", "colorScheme": "...", "darkMode": bool, "useWallpaperColors": bool, "generationMethod": "...", "paletteColors": [...] }]
      // Legacy entries omit "appearance" and use darkMode to infer light vs dark slot.
    }

    // applauncher
    property JsonObject appLauncher: JsonObject {
      property bool enableClipboardHistory: false
      property bool autoPasteClipboard: false
      property bool enableClipPreview: true
      property bool clipboardWrapText: true
      property bool enableClipboardSmartIcons: true
      property bool enableClipboardChips: true
      property string clipboardWatchTextCommand: "wl-paste --type text --watch cliphist store"
      property string clipboardWatchImageCommand: "wl-paste --type image --watch cliphist store"
      property string position: "center"  // Position: center, top_left, top_right, bottom_left, bottom_right, bottom_center, top_center
      property list<string> pinnedApps: []
      property bool sortByMostUsed: true
      property string terminalCommand: "alacritty -e"
      property bool customLaunchPrefixEnabled: false
      property string customLaunchPrefix: ""
      // View mode: "list" or "grid"
      property string viewMode: "list"
      property bool showCategories: true
      // Icon mode: "tabler" or "native"
      property string iconMode: "tabler"
      property bool showIconBackground: false
      property bool enableSettingsSearch: true
      property bool enableWindowsSearch: true
      property bool enableSessionSearch: true
      property bool ignoreMouseInput: false
      property string screenshotAnnotationTool: ""
      property bool overviewLayer: false
      property string density: "default" // "compact", "default", "comfortable"
    }

    // dashboard
    property JsonObject dashboard: JsonObject {
      // Position: close_to_bar_button, center, top_left, top_right, bottom_left, bottom_right, bottom_center, top_center
      property string position: "close_to_bar_button"
      // Fixed panel size in raw pixels. Deliberately not scaled by uiScaleRatio so the
      // dashboard keeps a predictable footprint across UI zoom levels; SmartPanel clamps
      // this to the available screen width/height, so oversize values degrade gracefully.
      property int panelWidth: 1400
      property int panelHeight: 700
      property string diskPath: "/"
      // Blurred album art behind the dashboard media card
      property JsonObject mediaBlur: JsonObject {
        property bool enabled: true
        // MultiEffect blur, 0.0-1.0
        property real strength: 1.0
      }
      property JsonObject mediaCard: JsonObject {
        // Frame drawn around the album artwork, in unscaled px. 0 = no frame.
        property int frameWidth: 0
        property string frameColor: "#ffffff"
      }
      property JsonObject shortcuts
      shortcuts: JsonObject {
        property list<var> left: [
          {
            "id": "Network"
          },
          {
            "id": "Bluetooth"
          },
          {
            "id": "WallpaperSelector"
          },
          {
            "id": "AgnocturalPerformance"
          }
        ]
        property list<var> right: [
          {
            "id": "Notifications"
          },
          {
            "id": "PowerProfile"
          },
          {
            "id": "KeepAwake"
          },
          {
            "id": "NightLight"
          }
        ]
      }
      property list<var> cards: [
        {
          "id": "profile-card",
          "enabled": true
        },
        {
          "id": "shortcuts-card",
          "enabled": true
        },
        {
          "id": "audio-card",
          "enabled": true
        },
        {
          "id": "brightness-card",
          "enabled": false
        },
        {
          "id": "weather-card",
          "enabled": true
        },
        {
          "id": "media-sysmon-card",
          "enabled": true
        }
      ]
    }

    // system monitor
    property JsonObject systemMonitor: JsonObject {
      property int cpuWarningThreshold: 80
      property int cpuCriticalThreshold: 90
      property int tempWarningThreshold: 80
      property int tempCriticalThreshold: 90
      property int gpuWarningThreshold: 80
      property int gpuCriticalThreshold: 90
      property int memWarningThreshold: 80
      property int memCriticalThreshold: 90
      property int swapWarningThreshold: 80
      property int swapCriticalThreshold: 90
      property int diskWarningThreshold: 80
      property int diskCriticalThreshold: 90
      property int diskAvailWarningThreshold: 20
      property int diskAvailCriticalThreshold: 10
      property int batteryWarningThreshold: 20
      property int batteryCriticalThreshold: 5
      property bool enableDgpuMonitoring: false // Opt-in: reading dGPU sysfs/nvidia-smi wakes it from D3cold, draining battery
      property bool useCustomColors: false
      property string warningColor: ""
      property string criticalColor: ""
      property string externalMonitor: "resources || missioncenter || jdsystemmonitor || corestats || system-monitoring-center || gnome-system-monitor || plasma-systemmonitor || mate-system-monitor || ukui-system-monitor || deepin-system-monitor || pantheon-system-monitor"
    }

    // dock
    property JsonObject dock: JsonObject {
      property bool enabled: true
      property string position: "bottom" // "top", "bottom", "left", "right"
      property string displayMode: "auto_hide" // "always_visible", "auto_hide", "exclusive"
      property string dockType: "floating" // "floating", "attached"
      property real backgroundOpacity: 1.0
      property real floatingRatio: 1.0
      property real size: 1
      property bool onlySameOutput: true
      property list<string> monitors: [] // holds dock visibility per monitor
      property list<string> pinnedApps: [] // Desktop entry IDs pinned to the dock (e.g., "org.kde.konsole", "firefox.desktop")
      property bool colorizeIcons: false
      property bool showLauncherIcon: false
      property string launcherPosition: "end" // "start", "end"
      property bool launcherUseDistroLogo: false
      property string launcherIcon: ""
      property string launcherIconColor: "none"
      property bool pinnedStatic: false
      property bool inactiveIndicators: false
      property bool groupApps: false
      property string groupContextMenuMode: "extended" // "list", "extended"
      property string groupClickAction: "cycle" // "cycle", "list"
      property string groupIndicatorStyle: "dots" // "number", "dots"
      property double deadOpacity: 0.6
      property real animationSpeed: 1.0 // Speed multiplier for hide/show animations (0.1 = slowest, 2.0 = fastest)
      property bool sitOnFrame: false
      property bool showDockIndicator: false
      property int indicatorThickness: 3
      property string indicatorColor: "primary"
      property real indicatorOpacity: 0.6
    }

    // network
    property JsonObject network: JsonObject {
      property bool bluetoothRssiPollingEnabled: false  // Opt-in Bluetooth RSSI polling (uses bluetoothctl)
      property int bluetoothRssiPollIntervalMs: 60000 // Polling interval in milliseconds for RSSI queries
      property string networkPanelView: "wifi"
      property string wifiDetailsViewMode: "grid"   // "grid" or "list"
      property string bluetoothDetailsViewMode: "grid" // "grid" or "list"
      property bool bluetoothHideUnnamedDevices: false
      property bool disableDiscoverability: false
      property bool bluetoothAutoConnect: true
    }

    // session menu
    property JsonObject sessionMenu: JsonObject {
      property bool enableCountdown: true
      property int countdownDuration: 10000
      property string position: "center"
      property bool showHeader: true
      property bool showKeybinds: true
      property bool largeButtonsStyle: true
      property string largeButtonsLayout: "single-row"
      property list<var> powerOptions: [
        {
          "action": "lock",
          "enabled": true,
          "keybind": "1"
        },
        {
          "action": "suspend",
          "enabled": true,
          "keybind": "2"
        },
        {
          "action": "hibernate",
          "enabled": true,
          "keybind": "3"
        },
        {
          "action": "reboot",
          "enabled": true,
          "keybind": "4"
        },
        {
          "action": "logout",
          "enabled": true,
          "keybind": "5"
        },
        {
          "action": "shutdown",
          "enabled": true,
          "keybind": "6"
        },
        {
          "action": "rebootToUefi",
          "enabled": true,
          "keybind": "7"
        }
      ]
    }

    // notifications
    property JsonObject notifications: JsonObject {
      property bool enabled: true
      property bool enableMarkdown: false
      property string density: "default" // "default", "compact"
      property list<string> monitors: [] // holds notifications visibility per monitor
      property string location: "top_right"
      property bool overlayLayer: true
      property real backgroundOpacity: 1.0
      property bool respectExpireTimeout: false
      property int lowUrgencyDuration: 3
      property int normalUrgencyDuration: 8
      property int criticalUrgencyDuration: 15
      property bool clearDismissed: true
      property JsonObject saveToHistory: JsonObject {
        property bool low: true
        property bool normal: true
        property bool critical: true
      }
      property JsonObject sounds: JsonObject {
        property bool enabled: false
        property real volume: 0.5
        property bool separateSounds: false
        property string criticalSoundFile: ""
        property string normalSoundFile: ""
        property string lowSoundFile: ""
        property string excludedApps: "discord,firefox,chrome,chromium,edge"
      }
      property bool enableMediaToast: false
      property bool enableKeyboardLayoutToast: true
      property bool enableBatteryToast: true
    }

    // on-screen display
    property JsonObject osd: JsonObject {
      property bool enabled: true
      property string location: "top_right"
      property int autoHideMs: 2000
      property bool overlayLayer: true
      property real backgroundOpacity: 1.0
      property list<var> enabledTypes: [OSD.Type.Volume, OSD.Type.InputVolume, OSD.Type.Brightness]
      property list<string> monitors: [] // holds osd visibility per monitor
    }

    // audio
    property JsonObject audio: JsonObject {
      property int volumeStep: 5
      property bool volumeOverdrive: false
      property int spectrumFrameRate: 30
      property string visualizerType: "linear"
      property bool spectrumMirrored: true
      property list<string> mprisBlacklist: []
      property string preferredPlayer: ""
      property bool volumeFeedback: false
      property string volumeFeedbackSoundFile: ""
    }

    // brightness
    property JsonObject brightness: JsonObject {
      property int brightnessStep: 5
      property bool enforceMinimum: true
      property bool enableDdcSupport: false
      property list<var> backlightDeviceMappings: []
      // Format: [{ "output": "eDP-1", "device": "/sys/class/backlight/intel_backlight" }]
    }

    property JsonObject colorSchemes: JsonObject {
      property bool useWallpaperColors: false
      property string predefinedScheme: "Mordial (default)"
      property bool darkMode: true
      property string schedulingMode: "off"
      property string manualSunrise: "06:30"
      property string manualSunset: "18:30"
      property string generationMethod: "tonal-spot"
      property string monitorForColors: ""
      property bool syncGsettings: true
      property JsonObject saturation: JsonObject {
        property real primary: 1.0
        property real secondary: 1.0
        property real tertiary: 1.0
        property real surface: 0.9
        property real background: 0.85
        property real error: 1.0
        property real outline: 0.7
      }
    }

    // templates toggles
    property JsonObject templates: JsonObject {
      property list<var> activeTemplates: []
      // Format: [{ "id": "gtk", "enabled": true }, { "id": "qt", "enabled": true }, ...]
      property bool enableUserTheming: false
    }

    // night light
    property JsonObject nightLight: JsonObject {
      property bool enabled: false
      property bool forced: false
      property bool autoSchedule: true
      property string nightTemp: "4000"
      property string dayTemp: "6500"
      property string manualSunrise: "06:30"
      property string manualSunset: "18:30"
    }

    // hooks
    property JsonObject hooks: JsonObject {
      property bool enabled: false
      property string wallpaperChange: ""
      property string darkModeChange: ""
      property string screenLock: ""
      property string screenUnlock: ""
      property string startup: ""
      property string session: ""
      property string colorGeneration: ""
    }

    // idle management
    property JsonObject idle: JsonObject {
      property bool enabled: false
      property int screenOffTimeout: 600    // seconds, 0 = disabled
      property int lockTimeout: 660         // seconds, 0 = disabled
      property int suspendTimeout: 1800     // seconds, 0 = disabled
      property int fadeDuration: 5       // seconds of fade-to-black before action fires
      property string screenOffCommand: ""
      property string lockCommand: ""
      property string suspendCommand: ""
      property string resumeScreenOffCommand: ""
      property string resumeLockCommand: ""
      property string resumeSuspendCommand: ""
      property string customCommands: "[]" // JSON array of {timeout, command, resumeCommand}
    }

    // desktop widgets
    property JsonObject desktopWidgets: JsonObject {
      property bool enabled: false
      property bool overviewEnabled: true
      property bool gridSnap: false
      property bool gridSnapScale: false
      property list<var> monitorWidgets: []
      // Format: [{ "name": "DP-1", "widgets": [...] }, { "name": "HDMI-1", "widgets": [...] }]
    }

    // AI chat
    property JsonObject aiChat: JsonObject {
      property string activeProvider: "ollama"
      property int maxHistoryLength: 100
      property JsonObject ollama: JsonObject {
        property string baseUrl: "http://localhost:11434"
        property string model: ""
        property real temperature: 0.7
        property string systemPrompt: "You are a helpful assistant integrated into a Linux desktop shell. Be concise and helpful."
      }
      property JsonObject lmstudio: JsonObject {
        property string baseUrl: "http://localhost:1234/v1/chat/completions"
        property string model: ""
        property real temperature: 0.7
        property string systemPrompt: "You are a helpful assistant integrated into a Linux desktop shell. Be concise and helpful."
      }
      property JsonObject internetSearch: JsonObject {
        property bool enabled: false
        property string provider: "duckduckgo"
        property int maxResults: 5
        property string searxngUrl: ""
        property bool searxngJsonMode: true
        property bool followUpRephrase: true
      }
    }
  }

  // -----------------------------------------------------
  // Preprocess paths by adding trailing "/"
  function ensureTrailingSlash(path) {
    return path.endsWith("/") ? path : path + "/";
  }

  // -----------------------------------------------------
  // Preprocess paths by expanding "~" to user's home directory
  function preprocessPath(path) {
    if (typeof path !== "string" || path === "") {
      return path;
    }

    // Expand "~" to user's home directory
    if (path.startsWith("~/")) {
      return Quickshell.env("HOME") + path.substring(1);
    } else if (path === "~") {
      return Quickshell.env("HOME");
    }

    return path;
  }

  // -----------------------------------------------------
  // Get default value for a setting path (e.g., "general.scaleRatio" or "bar.position")
  // Returns undefined if not found
  function getDefaultValue(path) {
    if (!root._defaultSettings) {
      return undefined;
    }

    var parts = path.split(".");
    var current = root._defaultSettings;

    for (var i = 0; i < parts.length; i++) {
      if (current === undefined || current === null) {
        return undefined;
      }
      current = current[parts[i]];
    }

    return current;
  }

  // -----------------------------------------------------
  // Compare current value with default value
  // Returns true if values differ, false if they match or default is not found
  function isValueChanged(path, currentValue) {
    var defaultValue = getDefaultValue(path);
    if (defaultValue === undefined) {
      return false; // Can't compare if default not found
    }

    // Deep comparison for objects and arrays
    if (typeof currentValue === "object" && typeof defaultValue === "object") {
      return JSON.stringify(currentValue) !== JSON.stringify(defaultValue);
    }

    // Simple comparison for primitives
    return currentValue !== defaultValue;
  }

  // -----------------------------------------------------
  // Format default value for tooltip display
  // Returns a human-readable string representation of the default value
  function formatDefaultValueForTooltip(path) {
    var defaultValue = getDefaultValue(path);
    if (defaultValue === undefined) {
      return "";
    }

    // Format based on type
    if (typeof defaultValue === "boolean") {
      return defaultValue ? "true" : "false";
    } else if (typeof defaultValue === "number") {
      return defaultValue.toString();
    } else if (typeof defaultValue === "string") {
      return defaultValue === "" ? "(empty)" : defaultValue;
    } else if (Array.isArray(defaultValue)) {
      return defaultValue.length === 0 ? "(empty)" : "[" + defaultValue.length + " items]";
    } else if (typeof defaultValue === "object") {
      return "(object)";
    }

    return String(defaultValue);
  }

  // -----------------------------------------------------
  // Helper to find a screen override entry by name in the array
  // Format: [{ "name": "HDMI-A-1", "position": "left" }, ...]
  // Note: QML's list<var> is not a true JS array, so we check for .length instead of Array.isArray()
  function _findScreenOverride(screenName) {
    var overrides = data.bar.screenOverrides;
    if (!screenName || !overrides || overrides.length === undefined) {
      return null;
    }
    for (var i = 0; i < overrides.length; i++) {
      if (overrides[i] && overrides[i].name === screenName) {
        return overrides[i];
      }
    }
    return null;
  }

  // Helper to find index of a screen override entry
  function _findScreenOverrideIndex(screenName) {
    var overrides = data.bar.screenOverrides;
    if (!screenName || !overrides || overrides.length === undefined) {
      return -1;
    }
    for (var i = 0; i < overrides.length; i++) {
      if (overrides[i] && overrides[i].name === screenName) {
        return i;
      }
    }
  }

  // -----------------------------------------------------
  // Check if a screen's overrides are enabled
  // Returns true if enabled flag is true or undefined (backward compat)
  // Returns false only if enabled is explicitly false
  function isScreenOverrideEnabled(screenName) {
    var override = _findScreenOverride(screenName);
    if (!override) {
      return false;
    }
    return override.enabled !== false;
  }

  // -----------------------------------------------------
  // Get effective bar position for a screen (with inheritance)
  // If the screen has a position override and overrides are enabled, use it; otherwise use global default
  function getBarPositionForScreen(screenName) {
    var override = _findScreenOverride(screenName);
    if (override && override.enabled !== false && override.position !== undefined) {
      return override.position;
    }
    return data.bar.position || "top";
  }

  // -----------------------------------------------------
  // Get effective bar widgets for a screen (with inheritance)
  // If the screen has widget overrides and overrides are enabled, use them; otherwise use global defaults
  function getBarWidgetsForScreen(screenName) {
    var override = _findScreenOverride(screenName);
    if (override && override.enabled !== false && override.widgets !== undefined) {
      return override.widgets;
    }
    return data.bar.widgets;
  }

  // -----------------------------------------------------
  // Get effective bar density for a screen (with inheritance)
  // If the screen has a density override and overrides are enabled, use it; otherwise use global default
  function getBarDensityForScreen(screenName) {
    var override = _findScreenOverride(screenName);
    if (override && override.enabled !== false && override.density !== undefined) {
      return override.density;
    }
    return data.bar.density || "default";
  }

  // -----------------------------------------------------
  // Get effective bar display mode for a screen (with inheritance)
  // If the screen has a displayMode override and overrides are enabled, use it; otherwise use global default
  function getBarDisplayModeForScreen(screenName) {
    var override = _findScreenOverride(screenName);
    if (override && override.enabled !== false && override.displayMode !== undefined) {
      return override.displayMode;
    }
    return data.bar.displayMode || "always_visible";
  }

  // -----------------------------------------------------
  // Check if a screen has any overrides, optionally for a specific property
  function hasScreenOverride(screenName, property) {
    var override = _findScreenOverride(screenName);
    if (!override) {
      return false;
    }
    if (property) {
      return override[property] !== undefined;
    }
    // Check if screen has any override property (besides "name")
    var keys = Object.keys(override);
    return keys.length > 1 || (keys.length === 1 && keys[0] !== "name");
  }

  // -----------------------------------------------------
  // Get the screen override entry directly (for in-place modifications)
  // Returns the actual entry object from the array, not a copy
  function getScreenOverrideEntry(screenName) {
    return _findScreenOverride(screenName);
  }

  // -----------------------------------------------------
  // Set a per-screen override
  function setScreenOverride(screenName, property, value) {
    if (!screenName)
      return;

    var overrides = JSON.parse(JSON.stringify(data.bar.screenOverrides || []));
    if (overrides.length === undefined) {
      overrides = [];
    }

    var index = -1;
    for (var i = 0; i < overrides.length; i++) {
      if (overrides[i] && overrides[i].name === screenName) {
        index = i;
        break;
      }
    }

    if (index === -1) {
      // Create new entry
      var newEntry = {
        "name": screenName
      };
      newEntry[property] = value;
      overrides.push(newEntry);
    } else {
      // Update existing entry
      overrides[index][property] = value;
    }
    data.bar.screenOverrides = overrides;
  }

  // -----------------------------------------------------
  // Clear a per-screen override (revert to global default)
  // If property is null, clears all overrides for that screen
  function clearScreenOverride(screenName, property) {
    if (!screenName)
      return;

    var overrides = data.bar.screenOverrides;
    if (!overrides || overrides.length === undefined) {
      return;
    }

    overrides = JSON.parse(JSON.stringify(overrides));

    var index = -1;
    for (var i = 0; i < overrides.length; i++) {
      if (overrides[i] && overrides[i].name === screenName) {
        index = i;
        break;
      }
    }

    if (index === -1) {
      return;
    }

    if (property) {
      delete overrides[index][property];
      // Remove screen entry if only "name" remains
      var keys = Object.keys(overrides[index]);
      if (keys.length <= 1 && (keys.length === 0 || keys[0] === "name")) {
        overrides.splice(index, 1);
      }
    } else {
      overrides.splice(index, 1);
    }
    data.bar.screenOverrides = overrides;
  }

  // -----------------------------------------------------
  // Public function to trigger immediate settings saving
  function saveImmediate() {
    settingsFileView.writeAdapter();
    root.settingsSaved(); // Emit signal after saving
  }

  // -----------------------------------------------------
  // Generate default settings: for reference only, not used by the shell
  function generateDefaultSettings() {
    try {
      Logger.d("Settings", "Generating settings-default.json");

      // Prepare a clean JSON
      var plainAdapter = QtObj2JS.qtObjectToPlainObject(adapter);
      var jsonData = JSON.stringify(plainAdapter, null, 2);

      var defaultPath = Quickshell.shellDir + "/Assets/settings-default.json";

      Quickshell.execDetached(["sh", "-c", `cat > "${defaultPath}" << 'MORDIAL_EOF'\n${jsonData}\nMORDIAL_EOF`]);
    } catch (error) {
      Logger.e("Settings", "Failed to generate default settings file: " + error);
    }
  }

  // -----------------------------------------------------
  // Generate default widget settings: for reference only, not used by the shell
  function generateWidgetDefaultSettings() {
    try {
      Logger.d("Settings", "Generating settings-widgets-default.json");

      var output = {
        "bar": QtObj2JS.qtObjectToPlainObject(BarWidgetRegistry.widgetMetadata),
        "dashboard": QtObj2JS.qtObjectToPlainObject(DashboardWidgetRegistry.widgetMetadata),
        "desktop": QtObj2JS.qtObjectToPlainObject(DesktopWidgetRegistry.widgetMetadata)
      };
      var jsonData = JSON.stringify(output, null, 2);

      var defaultPath = Quickshell.shellDir + "/Assets/settings-widgets-default.json";

      Quickshell.execDetached(["sh", "-c", `cat > "${defaultPath}" << 'MORDIAL_EOF'\n${jsonData}\nMORDIAL_EOF`]);
    } catch (error) {
      Logger.e("Settings", "Failed to generate widget default settings file: " + error);
    }
  }

  // -----------------------------------------------------
  // One-shot renames applied to the raw settings JSON before it reaches
  // the typed adapter. The adapter silently drops keys it no longer
  // declares, so a renamed section has to be copied across by hand.
  // Every step is gated on the presence of the old key, which makes the
  // whole thing idempotent and safe to re-run on an already-migrated file.
  function migrateRawSettings(raw) {
    if (!raw || typeof raw !== "object") {
      return;
    }

    // v60: controlCenter -> dashboard (panel section rename)
    if (raw.controlCenter && !raw.dashboard) {
      const cc = raw.controlCenter;
      if (cc.position !== undefined) {
        adapter.dashboard.position = cc.position;
      }
      if (cc.diskPath !== undefined) {
        adapter.dashboard.diskPath = cc.diskPath;
      }
      if (cc.cards !== undefined) {
        adapter.dashboard.cards = cc.cards;
      }
      if (cc.shortcuts) {
        if (cc.shortcuts.left !== undefined) {
          adapter.dashboard.shortcuts.left = cc.shortcuts.left;
        }
        if (cc.shortcuts.right !== undefined) {
          adapter.dashboard.shortcuts.right = cc.shortcuts.right;
        }
      }
      Logger.i("Settings", "Migrated 'controlCenter' settings section to 'dashboard'");
    }

    // v60: bar click action value + bar widget id renames
    const bar = raw.bar;
    if (bar) {
      for (const action of ["middleClickAction", "rightClickAction"]) {
        if (bar[action] === "controlCenter") {
          adapter.bar[action] = "dashboard";
          Logger.i("Settings", `Migrated bar.${action} from 'controlCenter' to 'dashboard'`);
        }
      }

      // The dashboard widget was renamed, so an existing bar layout would
      // otherwise have its button pruned as an unknown widget id. The array is
      // rebuilt and reassigned rather than mutated in place, because a plain
      // property write on a list<var> element does not mark the adapter dirty.
      for (const section of ["left", "center", "right"]) {
        const widgets = adapter.bar.widgets[section];
        let renamed = false;
        const migrated = widgets.map(widget => {
                                       if (widget.id === "ControlCenter") {
                                         renamed = true;
                                         return Object.assign({}, widget, {
                                                                id: "Dashboard"
                                                              });
                                       }
                                       return widget;
                                     });
        if (renamed) {
          adapter.bar.widgets[section] = migrated;
          Logger.i("Settings", `Migrated bar.${section} widget id 'ControlCenter' to 'Dashboard'`);
        }
      }
    }

    // v61: remove stale 'plugins' settings (plugin system removed)
    if (raw.plugins !== undefined) {
      delete raw.plugins;
      Logger.i("Settings", "Removed stale 'plugins' settings section (plugin system removed)");
    }

    // v62: rebrand Agnoctural -> Mordial
    // Migrate color scheme name
    if (raw.colorSchemes && raw.colorSchemes.predefinedScheme === "Agnoctural (default)") {
      adapter.colorSchemes.predefinedScheme = "Mordial (default)";
      Logger.i("Settings", "Migrated color scheme name from 'Agnoctural (default)' to 'Mordial (default)'");
    }
    // Migrate dashboard shortcut widget id
    if (raw.dashboard && raw.dashboard.shortcuts && raw.dashboard.shortcuts.left) {
      for (var i = 0; i < raw.dashboard.shortcuts.left.length; i++) {
        if (raw.dashboard.shortcuts.left[i].id === "AgnocturalPerformance") {
          adapter.dashboard.shortcuts.left[i].id = "MordialPerformance";
          Logger.i("Settings", "Migrated dashboard shortcut 'AgnocturalPerformance' to 'MordialPerformance'");
        }
      }
    }
  }

  // -----------------------------------------------------
  // If the settings structure has changed, ensure
  // backward compatibility by upgrading the settings
  function upgradeSettings() {
    // Wait for BarWidgetRegistry to be ready
    if (!BarWidgetRegistry.widgets || Object.keys(BarWidgetRegistry.widgets).length === 0) {
      Logger.d("Settings", "BarWidgetRegistry not ready, deferring upgrade");
      Qt.callLater(upgradeSettings);
      return;
    }

    // -----------------
    const sections = ["left", "center", "right"];

    // 1. remove any non existing bar widget type
    var removedWidget = false;
    for (var s = 0; s < sections.length; s++) {
      const sectionName = sections[s];
      const widgets = adapter.bar.widgets[sectionName];
      // Iterate backward through the widgets array, so it does not break when removing a widget
      for (var i = widgets.length - 1; i >= 0; i--) {
        var widget = widgets[i];
        if (!BarWidgetRegistry.hasWidget(widget.id)) {
          Logger.w(`Settings`, `!!! Deleted invalid bar widget ${widget.id} !!!`);
          widgets.splice(i, 1);
          removedWidget = true;
        }
      }
    }

    // -----------------
    // 2. remove any non existing dashboard widget type
    const ccSections = ["left", "right"];
    for (var s = 0; s < ccSections.length; s++) {
      const sectionName = ccSections[s];
      const shortcuts = adapter.dashboard.shortcuts[sectionName];
      for (var i = shortcuts.length - 1; i >= 0; i--) {
        var shortcut = shortcuts[i];
        if (!DashboardWidgetRegistry.hasWidget(shortcut.id)) {
          Logger.w(`Settings`, `!!! Deleted invalid dashboard widget ${shortcut.id} !!!`);
          shortcuts.splice(i, 1);
          removedWidget = true;
        }
      }
    }

    // -----------------
    // 3. remove any non existing desktop widget type
    const monitorWidgets = adapter.desktopWidgets.monitorWidgets;
    for (var m = 0; m < monitorWidgets.length; m++) {
      const monitor = monitorWidgets[m];
      if (!monitor.widgets)
        continue;
      for (var i = monitor.widgets.length - 1; i >= 0; i--) {
        var desktopWidget = monitor.widgets[i];
        if (!DesktopWidgetRegistry.hasWidget(desktopWidget.id)) {
          Logger.w(`Settings`, `!!! Deleted invalid desktop widget ${desktopWidget.id} !!!`);
          monitor.widgets.splice(i, 1);
          removedWidget = true;
        }
      }
    }

    // -----------------
    // 4. upgrade user widget settings
    for (var s = 0; s < sections.length; s++) {
      const sectionName = sections[s];
      for (var i = 0; i < adapter.bar.widgets[sectionName].length; i++) {
        var widget = adapter.bar.widgets[sectionName][i];

        // Check if widget registry supports user settings, if it does not, then there is nothing to do
        if (BarWidgetRegistry.widgetMetadata[widget.id] === undefined) {
          continue;
        }

        if (upgradeWidget(widget)) {
          Logger.d("Settings", `Upgraded ${widget.id} widget:`, JSON.stringify(widget));
        }
      }
    }
  }

  // -----------------------------------------------------
  // Function to clean up deprecated user/custom bar widgets settings
  function upgradeWidget(widget) {
    // Backup the widget definition before altering
    const widgetBefore = JSON.stringify(widget);

    // Get all existing custom settings keys
    const keys = Object.keys(BarWidgetRegistry.widgetMetadata[widget.id]);

    // Delete deprecated user settings from the wiget
    for (const k of Object.keys(widget)) {
      if (k === "id") {
        continue;
      }
      if (!keys.includes(k)) {
        delete widget[k];
      }
    }

    // Inject missing default setting (metaData) from BarWidgetRegistry
    for (var i = 0; i < keys.length; i++) {
      const k = keys[i];
      if (k === "id") {
        continue;
      }

      if (widget[k] === undefined) {
        widget[k] = BarWidgetRegistry.widgetMetadata[widget.id][k];
      }
    }

    // Compare settings, to detect if something has been upgraded
    const widgetAfter = JSON.stringify(widget);
    return (widgetAfter !== widgetBefore);
  }
}
