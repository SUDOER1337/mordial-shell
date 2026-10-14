/*
* Noctalia – made by https://github.com/noctalia-dev
* Licensed under the MIT License.
* Forks and modifications are allowed under the MIT License,
* but proper credit must be given to the original author.
*/

//@ pragma Env QT_FFMPEG_DECODING_HW_DEVICE_TYPES=vaapi,vdpau
//@ pragma Env QT_FFMPEG_ENCODING_HW_DEVICE_TYPES=vaapi,vdpau

// Qt & Quickshell Core
import QtQuick
import Quickshell

// Commons & Services
import qs.Commons

// Modules
import qs.Modules.Background
import qs.Modules.Bar
import qs.Modules.DesktopWidgets
import qs.Modules.Dock
import qs.Modules.LockScreen
import qs.Modules.MainScreen
import qs.Modules.Notification
import qs.Modules.OSD

import qs.Modules.Panels.Launcher
import qs.Modules.Panels.Settings
import qs.Modules.Panels.WindowSwitcher
import qs.Modules.Toast
import qs.Services.Control
import qs.Services.Hardware
import qs.Services.Keyboard
import qs.Services.Location
import qs.Services.Mordial
import qs.Services.Networking
import qs.Services.Power
import qs.Services.System
import qs.Services.Theming
import qs.Services.UI

ShellRoot {
  id: shellRoot

  property bool settingsLoaded: false
  property bool shellStateLoaded: false

  Component.onCompleted: {
    Logger.i("Shell", "---------------------------");
    Logger.i("Shell", "Mordial Hello!");
  }

  Connections {
    target: Quickshell
    function onReloadCompleted() {
      Quickshell.inhibitReloadPopup();
    }
    function onReloadFailed() {
      if (!Settings?.isDebug) {
        Quickshell.inhibitReloadPopup();
      }
    }
  }

  Connections {
    target: Settings ? Settings : null
    function onSettingsLoaded() {
      settingsLoaded = true;
    }
  }

  Connections {
    target: ShellState ? ShellState : null
    function onIsLoadedChanged() {
      if (ShellState.isLoaded) {
        shellStateLoaded = true;
      }
    }
  }

  Loader {
    active: settingsLoaded && shellStateLoaded

    sourceComponent: Item {
      Component.onCompleted: {
        Logger.i("Shell", "---------------------------");

        // Critical services needed for initial UI rendering
        WallpaperService.init();
        ImageCacheService.init();
        AppThemeService.init();
        ColorSchemeService.init();
        DarkModeService.init();

        // Defer non-critical services to unblock first frame
        Qt.callLater(function () {
          LocationService.init();
          NightLightService.apply();
          IdleInhibitorService.init();
          IdleService.init();
          PowerProfileService.init();
          HostService.init();
          NotificationRulesService.init();
          CustomButtonIPCService.init();
          IPCService.init(screenDetector);

          // Force ClipboardService initialization so clipboard watchers
          // start immediately instead of waiting for first launcher open
          if (Settings.data.appLauncher.enableClipboardHistory) {
            ClipboardService.checkCliphistAvailability();
          }
        });

        delayedInitTimer.restart();
      }

      Background {}
      DesktopWidgets {}
      AllScreens {}
      Dock {}
      Notification {}
      ToastOverlay {}
      OSD {}

      // Launcher overlay window (for overlay layer mode)
      Loader {
        active: Settings.data.appLauncher.overviewLayer
        sourceComponent: Component {
          LauncherOverlayWindow {}
        }
      }

      // Alt-Tab style window switcher overlay
      WindowSwitcherOverlayWindow {}

      LockScreen {}
      FadeOverlay {}

      // Settings window mode (single window across all monitors)
      SettingsPanelWindow {}

      // Shared screen detector for IPC
      CurrentScreenDetector {
        id: screenDetector
      }

      // IPCService is a singleton, initialized via init() in deferred services block
    }
  }

  // Delayed initialization
  Timer {
    id: delayedInitTimer
    running: false
    interval: 1500
    onTriggered: {
      HooksService.init();
      FontService.init();
      UpdateService.init();
    }
  }
}
