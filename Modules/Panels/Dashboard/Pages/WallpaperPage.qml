// File: Modules/Panels/Dashboard/Pages/WallpaperPage.qml
// =============================================================================
// Wallpaper picker — page 1 of the Dashboard (DashboardPanel.Page.Wallpaper).
// Grid-based browser for wallpapers with favorite toggling, view-mode cycling
// (grid/list), browse navigation, per-screen tabs and keyboard grid navigation.
//
// The Dashboard owns the panel frame, positioning and sizing; this page just
// fills the rectangle it is given (re-measuring its grid from that width) and
// forwards the Dashboard's keyboard handlers to the wallpaper grid.
//
// Functions:
//   onPageShown()             - Reset state and focus the search input
//   onDownPressed()           - Move grid selection down
//   onUpPressed()             - Move grid selection up
//   onLeftPressed()           - Move grid selection left
//   onRightPressed()          - Move grid selection right
//   onReturnPressed()         - Apply the selected wallpaper
//   selectItem(path, isDir)  - Navigate into directory or select wallpaper
//   cycleViewMode()           - Toggle between grid and list view
//   refreshWallpaperScreenData() - Re-scan wallpapers for current screen
//   sortFavoritesToTop(items) - Reorder items with favorites first
//
// Properties:
//   currentScreenIndex        - Index into Quickshell.screens for the active view
//   filterText                - Debounced search query
//   appearanceTabIndex        - 0 = light wallpaper, 1 = dark wallpaper
//   screenRepeater            - Per-screen wallpaper views
// =============================================================================

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Modules.Panels.Settings
import qs.Services.Theming
import qs.Services.UI
import qs.Widgets

Rectangle {
  id: root
  color: "transparent"

  property ShellScreen screen

  // The Dashboard owns the panel size, so this page does not ask for one: it
  // fills whatever rectangle the Dashboard hands it. Its grid re-measures itself
  // from that width (see wallpaperGridView.columns).

  // Raised by the page's close button; the Dashboard owns the panel frame.
  signal closeRequested

  // Page-level state, shared with the per-screen views below.
  property int currentScreenIndex: {
    if (screen !== null) {
      for (var i = 0; i < Quickshell.screens.length; i++) {
        if (Quickshell.screens[i].name == screen.name) {
          return i;
        }
      }
    }
    return 0;
  }
  property string filterText: ""
  property int appearanceTabIndex: 0
  readonly property bool headerScreensStripAvailable: !Settings.data.wallpaper.setWallpaperOnAllMonitors || Settings.data.wallpaper.enableMultiMonitorDirectories
  readonly property bool headerDevicesButtonVisible: Quickshell.screens.length > 1 || Settings.data.wallpaper.enableMultiMonitorDirectories
  property alias screenRepeater: screenRepeater

  // The Dashboard calls this when the page becomes visible, so the state and
  // focus match what the standalone panel used to do on open.
  function onPageShown() {
    for (var i = 0; i < screenRepeater.count; i++) {
      let item = screenRepeater.itemAt(i);
      if (item && item.gridView) {
        item.gridView.currentIndex = -1;
      }
    }
    root.appearanceTabIndex = Settings.data.colorSchemes.darkMode ? 1 : 0;
    WallpaperService.wallpaperSelectionAppearance = root.appearanceTabIndex === 1 ? "dark" : "light";
    // Give initial focus to search input
    Qt.callLater(() => {
                   if (searchInput.inputItem) {
                     searchInput.inputItem.forceActiveFocus();
                   }
                 });
  }

  // Keyboard handlers, delegated here by the Dashboard so the grid keeps its
  // navigation while this page is active.
  function onDownPressed() {
    if (!screenRepeater)
      return;
    let view = screenRepeater.itemAt(currentScreenIndex);
    if (view?.gridView) {
      if (!view.gridView.hasActiveFocus) {
        view.gridView.forceActiveFocus();
        if (view.gridView.currentIndex < 0 && view.gridView.model.length > 0) {
          view.gridView.currentIndex = 0;
        }
      } else {
        if (view.gridView.currentIndex < 0 && view.gridView.model.length > 0) {
          view.gridView.currentIndex = 0;
        } else {
          view.gridView.moveCurrentIndexDown();
        }
      }
    }
  }

  function onUpPressed() {
    if (!screenRepeater)
      return;
    let view = screenRepeater.itemAt(currentScreenIndex);
    if (view?.gridView?.hasActiveFocus) {
      if (view.gridView.currentIndex < 0 && view.gridView.model.length > 0) {
        view.gridView.currentIndex = 0;
      } else {
        view.gridView.moveCurrentIndexUp();
      }
    }
  }

  function onLeftPressed() {
    if (!screenRepeater)
      return;
    let view = screenRepeater.itemAt(currentScreenIndex);
    if (view?.gridView?.hasActiveFocus) {
      if (view.gridView.currentIndex < 0 && view.gridView.model.length > 0) {
        view.gridView.currentIndex = 0;
      } else {
        view.gridView.moveCurrentIndexLeft();
      }
    }
  }

  function onRightPressed() {
    if (!screenRepeater)
      return;
    let view = screenRepeater.itemAt(currentScreenIndex);
    if (view?.gridView?.hasActiveFocus) {
      if (view.gridView.currentIndex < 0 && view.gridView.model.length > 0) {
        view.gridView.currentIndex = 0;
      } else {
        view.gridView.moveCurrentIndexRight();
      }
    }
  }

  function onReturnPressed() {
    if (!screenRepeater)
      return;

    let view = screenRepeater.itemAt(currentScreenIndex);
    if (view?.gridView?.hasActiveFocus) {
      let gridView = view.gridView;
      if (gridView.currentIndex >= 0 && gridView.currentIndex < gridView.model.count) {
        var item = gridView.model.get(gridView.currentIndex);
        view.selectItem(item.path, item.isDirectory);
      }
    }
  }

  function onEnterPressed() {
    onReturnPressed();
  }

  // Solid color picker dialog
  NColorPickerDialog {
    id: solidColorPicker
    screen: root.screen
    selectedColor: Settings.data.wallpaper.solidColor
    onColorSelected: color => WallpaperService.setSolidColor(color.toString())
  }

  // Debounce timer for search
  Timer {
    id: searchDebounceTimer
    interval: 150
    onTriggered: {
      root.filterText = searchInput.text;
      // Trigger update on all screen views
      for (var i = 0; i < screenRepeater.count; i++) {
        let item = screenRepeater.itemAt(i);
        if (item && item.updateFiltered) {
          item.updateFiltered();
        }
      }
    }
  }

  ColumnLayout {
    anchors.fill: parent
    anchors.margins: Style.marginL
    spacing: Style.marginM

    // Header
    NBox {
      Layout.fillWidth: true
      Layout.preferredHeight: headerColumn.implicitHeight + Style.margin2L
      color: Color.mSurfaceVariant

      ColumnLayout {
        id: headerColumn
        anchors.fill: parent
        anchors.margins: Style.marginL
        spacing: Style.marginM

        RowLayout {
          Layout.fillWidth: true
          spacing: Style.marginM

          NIcon {
            icon: "settings-wallpaper-selector"
            pointSize: Style.fontSizeXXL
            color: Color.mPrimary
          }

          NText {
            text: "Wallpaper Selector"
            pointSize: Style.fontSizeL
            font.weight: Style.fontWeightBold
            color: Color.mOnSurface
            Layout.fillWidth: true
          }

          NIconButton {
            visible: Settings.data.wallpaper.enabled
            icon: "dark-mode"
            tooltipText: Settings.data.wallpaper.linkLightAndDarkWallpapers ? "Auto-switch wallpaper with theme" : "Keep wallpaper when switching theme"
            baseSize: Style.baseWidgetSize * 0.8
            colorBg: !Settings.data.wallpaper.linkLightAndDarkWallpapers ? Color.mPrimary : Color.smartAlpha(Color.mSurfaceVariant)
            colorFg: !Settings.data.wallpaper.linkLightAndDarkWallpapers ? Color.mOnPrimary : Color.mPrimary
            onClicked: Settings.data.wallpaper.linkLightAndDarkWallpapers = !Settings.data.wallpaper.linkLightAndDarkWallpapers
          }

          NIconButton {
            visible: Settings.data.wallpaper.enabled && root.headerDevicesButtonVisible
            icon: "devices"
            tooltipText: Settings.data.wallpaper.setWallpaperOnAllMonitors ? "Choose wallpaper per monitor" : "Apply to all monitors"
            baseSize: Style.baseWidgetSize * 0.8
            colorBg: !Settings.data.wallpaper.setWallpaperOnAllMonitors ? Color.mPrimary : Color.smartAlpha(Color.mSurfaceVariant)
            colorFg: !Settings.data.wallpaper.setWallpaperOnAllMonitors ? Color.mOnPrimary : Color.mPrimary
            onClicked: Settings.data.wallpaper.setWallpaperOnAllMonitors = !Settings.data.wallpaper.setWallpaperOnAllMonitors
          }

          NIconButton {
            icon: "palette"
            tooltipText: "Solid color background"
            baseSize: Style.baseWidgetSize * 0.8
            colorBg: Settings.data.wallpaper.useSolidColor ? Color.mPrimary : Color.mSurfaceVariant
            colorFg: Settings.data.wallpaper.useSolidColor ? Color.mOnPrimary : Color.mPrimary
            onClicked: solidColorPicker.open()
          }

          NIconButton {
            icon: "settings"
            tooltipText: "Wallpaper settings"
            baseSize: Style.baseWidgetSize * 0.8
            onClicked: {
              SettingsPanelService.openToTab(SettingsPanel.Tab.Wallpaper, -1, root.screen);
            }
          }

          NIconButton {
            icon: "close"
            tooltipText: "Close"
            baseSize: Style.baseWidgetSize * 0.8
            onClicked: root.closeRequested()
          }
        }

        NDivider {
          Layout.fillWidth: true
        }

        NTabBar {
          id: appearanceTabBar
          visible: Settings.data.wallpaper.enabled && !Settings.data.wallpaper.linkLightAndDarkWallpapers
          Layout.fillWidth: true
          currentIndex: root.appearanceTabIndex
          spacing: Style.marginM
          distributeEvenly: true

          onCurrentIndexChanged: {
            if (currentIndex < 0) {
              return;
            }
            root.appearanceTabIndex = currentIndex;
            WallpaperService.wallpaperSelectionAppearance = currentIndex === 1 ? "dark" : "light";
            Settings.data.colorSchemes.darkMode = currentIndex === 1;
          }

          NTabButton {
            text: "Light"
            tabIndex: 0
            checked: appearanceTabBar.currentIndex === 0
          }
          NTabButton {
            text: "Dark"
            tabIndex: 1
            checked: appearanceTabBar.currentIndex === 1
          }
        }

        NTabBar {
          id: screenTabBar
          visible: root.headerScreensStripAvailable
          Layout.fillWidth: true
          currentIndex: currentScreenIndex
          onCurrentIndexChanged: currentScreenIndex = currentIndex
          spacing: Style.marginM
          distributeEvenly: true

          Repeater {
            model: Quickshell.screens
            NTabButton {
              required property var modelData
              required property int index
              text: modelData.name || `Screen ${index + 1}`
              tabIndex: index
              checked: {
                screenTabBar.currentIndex === index;
              }
            }
          }
        }

        // Unified search input and source
        RowLayout {
          Layout.fillWidth: true
          spacing: Style.marginM

          NTextInput {
            id: searchInput
            placeholderText: "Type to filter wallpapers..."
            fontSize: Style.fontSizeM
            Layout.fillWidth: true

            property bool initializing: true
            Component.onCompleted: {
              searchInput.text = root.filterText || "";
              if (searchInput.inputItem && searchInput.inputItem.visible) {
                searchInput.inputItem.forceActiveFocus();
              }
              Qt.callLater(function () {
                searchInput.initializing = false;
              });
            }

            onTextChanged: {
              if (initializing) {
                return;
              }
              searchDebounceTimer.restart();
            }

            Keys.onPressed: event => {
                              if (Keybinds.checkKey(event, 'down', Settings)) {
                                let currentView = screenRepeater.itemAt(currentScreenIndex);
                                if (currentView && currentView.gridView) {
                                  currentView.gridView.forceActiveFocus();
                                }
                                event.accepted = true;
                              }
                            }
          }

          NIconButton {
            icon: "color-swatch"
            tooltipText: Settings.data.colorSchemes.useWallpaperColors ? "Use predefined color schemes" : "Use wallpaper color extraction"
            baseSize: Style.baseWidgetSize * 0.8
            onClicked: {
              Settings.data.colorSchemes.useWallpaperColors = !Settings.data.colorSchemes.useWallpaperColors;
              if (Settings.data.colorSchemes.useWallpaperColors) {
                AppThemeService.generate();
              } else {
                ColorSchemeService.setPredefinedScheme(Settings.data.colorSchemes.predefinedScheme);
              }
            }
          }

          NComboBox {
            id: colorSchemeComboBox
            Layout.fillWidth: false
            Layout.minimumWidth: 200
            minimumWidth: 200

            property bool _initialized: false
            property bool _userChanging: false
            Component.onCompleted: Qt.callLater(() => {
                                                  _initialized = true;
                                                })

            model: Settings.data.colorSchemes.useWallpaperColors ? TemplateProcessor.schemeTypes : ColorSchemeService.schemes.map(s => ({
                                                                                                                                          "key": ColorSchemeService.getBasename(s),
                                                                                                                                          "name": ColorSchemeService.getBasename(s)
                                                                                                                                        }))
            currentKey: Settings.data.colorSchemes.useWallpaperColors ? Settings.data.colorSchemes.generationMethod : Settings.data.colorSchemes.predefinedScheme
            onCurrentKeyChanged: {
              if (!_initialized)
                return;
              if (_userChanging) {
                _userChanging = false;
                return;
              }
              schemeGlowAnimation.restart();
            }
            onSelected: key => {
                          _userChanging = true;
                          if (Settings.data.colorSchemes.useWallpaperColors) {
                            Settings.data.colorSchemes.generationMethod = key;
                            AppThemeService.generate();
                          } else {
                            ColorSchemeService.setPredefinedScheme(key);
                          }
                          Qt.callLater(() => {
                                         _userChanging = false;
                                       });
                        }

            SequentialAnimation {
              id: schemeGlowAnimation
              NumberAnimation {
                target: colorSchemeComboBox
                property: "opacity"
                to: 0.3
                duration: Style.animationSlow
                easing.type: Easing.OutCubic
              }
              NumberAnimation {
                target: colorSchemeComboBox
                property: "opacity"
                to: 1.0
                duration: Style.animationSlow
                easing.type: Easing.InCubic
              }
            }
          }

          NText {
            text: "Source: Local"
            color: Color.mOnSurfaceVariant
            pointSize: Style.fontSizeS
            Layout.alignment: Qt.AlignVCenter
          }
        }
      }
    }

    // Local wallpaper view
    NBox {
      Layout.fillWidth: true
      Layout.fillHeight: true
      color: Color.mSurfaceVariant

      StackLayout {
        id: screenStack
        anchors.fill: parent
        anchors.margins: Style.marginL
        currentIndex: currentScreenIndex

        Repeater {
          id: screenRepeater
          model: Quickshell.screens
          delegate: WallpaperScreenView {
            targetScreen: modelData
          }
        }
      }
    }
  }

  // Component for each screen's wallpaper view
  component WallpaperScreenView: Item {
    id: wallpaperScreenView
    property var targetScreen
    property alias gridView: wallpaperGridView

    // Local reactive state for this screen
    property list<string> wallpapersList: []
    property string currentWallpaper: ""
    property var filteredItems: [] // Combined list of { path, name, isDirectory }
    property var wallpapersWithNames: [] // Cached basenames for files
    property var directoriesList: [] // List of directories in browse mode

    // ListModel for the grid — enables animated reordering via move()
    ListModel {
      id: wallpaperModel
    }

    // Browse mode properties
    property string currentBrowsePath: WallpaperService.getCurrentBrowsePath(targetScreen?.name ?? "")
    property bool isBrowseMode: Settings.data.wallpaper.viewMode === "browse"
    property int _browseScanGeneration: 0

    // Favorited paths (any light/dark) first, then the rest
    function sortFavoritesToTop(items) {
      var favs = [];
      var rest = [];
      for (var i = 0; i < items.length; i++) {
        var it = items[i];
        if (!it.isDirectory && WallpaperService.isFavorite(it.path)) {
          favs.push(it);
        } else {
          rest.push(it);
        }
      }
      return favs.concat(rest);
    }

    // Rebuild filteredItems and sync to wallpaperModel (full replacement, no animation).
    // When skipSync is true the caller will animate the model itself.
    function updateFiltered(skipSync) {
      var combinedItems = [];

      // In browse mode, add directories first
      if (isBrowseMode) {
        for (var i = 0; i < directoriesList.length; i++) {
          var dirPath = directoriesList[i];
          combinedItems.push({
                               "path": dirPath,
                               "name": dirPath.split('/').pop(),
                               "isDirectory": true
                             });
        }
      }

      // Add files
      for (var i = 0; i < wallpapersList.length; i++) {
        combinedItems.push({
                             "path": wallpapersList[i],
                             "name": wallpapersList[i].split('/').pop(),
                             "isDirectory": false
                           });
      }

      combinedItems = sortFavoritesToTop(combinedItems);

      // Apply filter if text is present
      if (!root.filterText || root.filterText.trim().length === 0) {
        filteredItems = combinedItems;
        if (!skipSync)
          syncModel();
        return;
      }

      const results = FuzzySort.go(root.filterText.trim(), combinedItems, {
                                     "key": 'name',
                                     "limit": 200
                                   });
      var filtered = results.map(function (r) {
        return r.obj;
      });
      filteredItems = sortFavoritesToTop(filtered);
      if (!skipSync)
        syncModel();
    }

    // Copy filteredItems into the ListModel (full rebuild, no animation).
    function syncModel() {
      wallpaperModel.clear();
      for (var i = 0; i < filteredItems.length; i++) {
        wallpaperModel.append(filteredItems[i]);
      }
      wallpaperGridView.currentIndex = -1;
      wallpaperGridView.positionViewAtBeginning();
    }

    // Animate a single item moving to its new position after a favorite toggle.
    function handleFavoriteMove(path) {
      // Find where the item currently sits in the model
      var fromIndex = -1;
      for (var i = 0; i < wallpaperModel.count; i++) {
        if (wallpaperModel.get(i).path === path) {
          fromIndex = i;
          break;
        }
      }
      if (fromIndex === -1)
        return;

      // Find where it should be in the freshly-computed filteredItems
      var toIndex = -1;
      for (var j = 0; j < filteredItems.length; j++) {
        if (filteredItems[j].path === path) {
          toIndex = j;
          break;
        }
      }
      if (toIndex === -1 || fromIndex === toIndex)
        return;

      wallpaperGridView.animateMovement = true;
      wallpaperModel.move(fromIndex, toIndex, 1);
      animateMovementResetTimer.restart();
    }

    // Turn off move animations shortly after the move completes so that
    // non-favorite model rebuilds (sort, filter, navigation) don't animate.
    Timer {
      id: animateMovementResetTimer
      readonly property int settleDelay: 50
      interval: Style.animationNormal + settleDelay
      onTriggered: {
        wallpaperGridView.animateMovement = false;
        reconcileModel();
      }
    }

    // Reorder wallpaperModel to match filteredItems using in-place moves.
    // Avoids clear+rebuild which would destroy delegates and flash thumbnails.
    function reconcileModel() {
      for (var i = 0; i < filteredItems.length; i++) {
        var currentPos = -1;
        for (var j = i; j < wallpaperModel.count; j++) {
          if (wallpaperModel.get(j).path === filteredItems[i].path) {
            currentPos = j;
            break;
          }
        }
        if (currentPos !== -1 && currentPos !== i) {
          wallpaperModel.move(currentPos, i, 1);
        }
      }
    }

    Component.onCompleted: {
      refreshWallpaperScreenData();
    }

    Connections {
      target: WallpaperService
      function onWallpaperChanged(screenName, path) {
        if (targetScreen !== null && screenName === targetScreen.name) {
          currentWallpaper = WallpaperService.getWallpaperPathForSlot(targetScreen.name, WallpaperService.wallpaperSelectionAppearance);
        }
      }
      function onWallpaperSelectionAppearanceChanged() {
        if (targetScreen !== null) {
          currentWallpaper = WallpaperService.getWallpaperPathForSlot(targetScreen.name, WallpaperService.wallpaperSelectionAppearance);
          updateFiltered(false);
        }
      }
      function onWallpaperDirectoryChanged(screenName, directory) {
        if (targetScreen !== null && screenName === targetScreen.name) {
          // Reset browse path when root directory changes
          if (isBrowseMode) {
            WallpaperService.navigateToRoot(targetScreen.name);
          }
          refreshWallpaperScreenData();
        }
      }
      function onWallpaperListChanged(screenName, count) {
        if (targetScreen !== null && screenName === targetScreen.name) {
          refreshWallpaperScreenData();
        }
      }
      function onBrowsePathChanged(screenName, path) {
        if (targetScreen !== null && screenName === targetScreen.name) {
          currentBrowsePath = path;
          refreshWallpaperScreenData();
        }
      }
      function onFavoritesChanged(path) {
        updateFiltered(true);   // recompute filteredItems but skip full model rebuild
        handleFavoriteMove(path); // animate the item to its new position
      }
    }

    function refreshWallpaperScreenData() {
      if (targetScreen === null) {
        return;
      }

      currentWallpaper = WallpaperService.getWallpaperPathForSlot(targetScreen.name, WallpaperService.wallpaperSelectionAppearance);

      if (isBrowseMode) {
        // In browse mode, scan current directory for both files and directories
        var browsePath = WallpaperService.getCurrentBrowsePath(targetScreen.name);
        currentBrowsePath = browsePath;

        // Bump generation so stale scan callbacks from rapid navigation are ignored
        var gen = ++_browseScanGeneration;
        WallpaperService.scanDirectoryWithDirs(targetScreen.name, browsePath, function (result) {
          if (gen !== _browseScanGeneration)
            return; // Stale callback from a superseded navigation
          wallpapersList = result.files;
          directoriesList = result.directories;
          Logger.d("WallpaperPanel", "Browse mode: Got", wallpapersList.length, "files and", directoriesList.length, "directories for screen", targetScreen.name);
          updateFiltered();
        });
      } else {
        // Normal mode: just use the wallpaper list from service
        wallpapersList = WallpaperService.getWallpapersList(targetScreen.name);
        directoriesList = [];
        Logger.d("WallpaperPanel", "Got", wallpapersList.length, "wallpapers for screen", targetScreen.name);
        updateFiltered();
      }
    }

    function selectItem(path, isDirectory) {
      if (isDirectory) {
        WallpaperService.setBrowsePath(targetScreen.name, path);
      } else {
        var screen = Settings.data.wallpaper.setWallpaperOnAllMonitors ? undefined : targetScreen.name;
        WallpaperService.changeWallpaper(path, screen, WallpaperService.wallpaperSelectionAppearance);
        WallpaperService.applyFavoriteTheme(path, screen, WallpaperService.wallpaperSelectionAppearance);
      }
    }

    // Helper function to cycle view modes
    function cycleViewMode() {
      var mode = Settings.data.wallpaper.viewMode;
      if (mode === "single") {
        Settings.data.wallpaper.viewMode = "recursive";
      } else if (mode === "recursive") {
        Settings.data.wallpaper.viewMode = "browse";
      } else {
        Settings.data.wallpaper.viewMode = "single";
      }
    }

    // Helper function to get icon for current view mode
    function getViewModeIcon() {
      var mode = Settings.data.wallpaper.viewMode;
      if (mode === "single")
        return "folder";
      if (mode === "recursive")
        return "folders";
      return "folder-open";
    }

    // Helper function to get tooltip for current view mode
    function getViewModeTooltip() {
      var mode = Settings.data.wallpaper.viewMode;
      var modeName;
      if (mode === "single")
        modeName = "Root directory";
      else if (mode === "recursive")
        modeName = "Flattened subdirectories";
      else
        modeName = "Browse directories";
      return "View mode: {mode} (click to change)".replace("{mode}", modeName);
    }

    ColumnLayout {
      anchors.fill: parent
      spacing: Style.marginM

      // Combined toolbar: navigation (left) + actions (right)
      RowLayout {
        Layout.fillWidth: true
        spacing: Style.marginS

        // Left side: navigation (back, home, path)
        NIconButton {
          icon: "arrow-left"
          tooltipText: "Go to parent folder"
          enabled: isBrowseMode && currentBrowsePath !== WallpaperService.getMonitorDirectory(targetScreen?.name ?? "")
          onClicked: WallpaperService.navigateUp(targetScreen?.name ?? "")
          baseSize: Style.baseWidgetSize * 0.8
        }

        NIconButton {
          icon: "home"
          tooltipText: "Go to wallpaper root"
          enabled: isBrowseMode && currentBrowsePath !== WallpaperService.getMonitorDirectory(targetScreen?.name ?? "")
          onClicked: WallpaperService.navigateToRoot(targetScreen?.name ?? "")
          baseSize: Style.baseWidgetSize * 0.8
        }

        NScrollText {
          text: isBrowseMode ? currentBrowsePath : WallpaperService.getMonitorDirectory(targetScreen?.name ?? "")
          Layout.fillWidth: true
          scrollMode: NScrollText.ScrollMode.Hover
          fadeCornerRadius: Style.radiusM

          NText {
            text: isBrowseMode ? currentBrowsePath : WallpaperService.getMonitorDirectory(targetScreen?.name ?? "")
            pointSize: Style.fontSizeS
            color: Color.mOnSurfaceVariant
          }
        }

        // Right side: actions (view mode, hide filenames, refresh)
        NIconButton {
          property string sortOrder: Settings.data.wallpaper.sortOrder || "name"
          icon: {
            if (sortOrder === "date_desc")
              return "clock";
            if (sortOrder === "date_asc")
              return "history";
            if (sortOrder === "name_desc")
              return "sort-descending";
            if (sortOrder === "random")
              return "arrows-shuffle";
            return "sort-ascending";
          }
          tooltipText: {
            if (sortOrder === "date_desc")
              return "Sort by newest first";
            if (sortOrder === "date_asc")
              return "Sort by oldest first";
            if (sortOrder === "name_desc")
              return "Sort by name (Z-A)";
            if (sortOrder === "random")
              return "Sort by random";
            return "Sort by name (A-Z)";
          }
          baseSize: Style.baseWidgetSize * 0.8
          onClicked: {
            var next = "name";
            if (sortOrder === "name")
              next = "date_desc";
            else if (sortOrder === "date_desc")
              next = "name"; // Toggle simpler: Name -> Newest -> Name
            // Expanded cycle: Name -> Newest -> Oldest -> Z-A -> Random -> Name
            // User just asked for "newest first", so let's make it easy to reach.
            // Let's do: Name (A-Z) -> Newest -> Oldest -> Name (Z-A) -> ...

            if (sortOrder === "name")
              next = "date_desc";
            else if (sortOrder === "date_desc")
              next = "date_asc";
            else if (sortOrder === "date_asc")
              next = "name_desc";
            else if (sortOrder === "name_desc")
              next = "random";
            else
              next = "name";

            Settings.data.wallpaper.sortOrder = next;
          }
        }

        NIconButton {
          icon: getViewModeIcon()
          tooltipText: getViewModeTooltip()
          baseSize: Style.baseWidgetSize * 0.8
          onClicked: cycleViewMode()
        }

        NIconButton {
          icon: Settings.data.wallpaper.hideWallpaperFilenames ? "id-off" : "id"
          tooltipText: Settings.data.wallpaper.hideWallpaperFilenames ? "Show filenames" : "Hide filenames"
          baseSize: Style.baseWidgetSize * 0.8
          onClicked: Settings.data.wallpaper.hideWallpaperFilenames = !Settings.data.wallpaper.hideWallpaperFilenames
        }

        NIconButton {
          icon: Settings.data.wallpaper.showHiddenFiles ? "eye" : "eye-closed"
          tooltipText: Settings.data.wallpaper.showHiddenFiles ? "Hide hidden files" : "Show hidden files"
          baseSize: Style.baseWidgetSize * 0.8
          onClicked: Settings.data.wallpaper.showHiddenFiles = !Settings.data.wallpaper.showHiddenFiles
        }

        NIconButton {
          icon: "refresh"
          tooltipText: "Refresh wallpaper list"
          baseSize: Style.baseWidgetSize * 0.8
          onClicked: {
            if (isBrowseMode) {
              refreshWallpaperScreenData();
            } else {
              WallpaperService.refreshWallpapersList();
            }
          }
        }
      }

      NGridView {
        id: wallpaperGridView

        Layout.fillWidth: true
        Layout.fillHeight: true

        visible: !WallpaperService.scanning
        interactive: true
        keyNavigationEnabled: true
        keyNavigationWraps: false
        highlightFollowsCurrentItem: false
        currentIndex: -1

        model: wallpaperModel

        Component.onCompleted: {
          positionViewAtBeginning();
        }

        // Column count follows the width the Dashboard actually gives this page,
        // not the screen's: the panel is a fixed, user-configurable size, so a
        // wide panel should show more thumbnails and a narrow one fewer instead
        // of overflowing or leaving the row half empty. Deriving columns from
        // availableWidth (rather than cellWidth) keeps this acyclic - cellWidth
        // is computed from columns, never the reverse.
        property int targetCellWidth: 240
        property int columns: Math.max(3, Math.floor((availableWidth - leftMargin - rightMargin) / targetCellWidth))
        property int itemSize: cellWidth

        cellWidth: Math.floor((availableWidth - leftMargin - rightMargin) / columns)
        cellHeight: Math.floor(itemSize * 0.7) + Style.marginXS + Style.fontSizeXS + Style.marginM

        leftMargin: Style.marginS
        rightMargin: Style.marginS
        topMargin: Style.marginS
        bottomMargin: Style.marginS

        onCurrentIndexChanged: {
          if (currentIndex >= 0) {
            positionViewAtIndex(currentIndex, GridView.Contain);
          }
        }

        onKeyPressed: event => {
                        if (Keybinds.checkKey(event, 'enter', Settings)) {
                          if (currentIndex >= 0 && currentIndex < filteredItems.length) {
                            selectItem(filteredItems[currentIndex]);
                          }
                          event.accepted = true;
                        }
                      }

        delegate: Item {
          id: wallpaperItemWrapper
          width: wallpaperGridView.cellWidth
          height: wallpaperGridView.cellHeight

          ColumnLayout {
            id: wallpaperItem
            anchors.fill: parent
            anchors.margins: Style.marginXS

            property string wallpaperPath: model.path ?? ""
            property bool isDirectory: model.isDirectory ?? false
            property bool isSelected: !isDirectory && (wallpaperPath === currentWallpaper)
            property bool isFavorited: {
              WallpaperService.favoritesRevision;
              return !isDirectory && WallpaperService.isFavorite(wallpaperPath);
            }
            property string filename: model.name ?? wallpaperPath.split('/').pop()
            property string cachedPath: ""

            spacing: Style.marginXS

            Component.onCompleted: {
              if (!isDirectory && ImageCacheService.initialized) {
                ImageCacheService.getThumbnail(wallpaperPath, function (path, success) {
                  if (wallpaperItem)
                    wallpaperItem.cachedPath = success ? path : wallpaperPath;
                });
              } else if (!isDirectory) {
                cachedPath = wallpaperPath;
              }
            }

            Item {
              id: imageContainer
              Layout.fillWidth: true
              Layout.fillHeight: true

              property real imageHeight: Math.round(wallpaperGridView.itemSize * 0.67)

              // Directory display
              Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                height: imageContainer.imageHeight
                color: Color.mSurfaceVariant
                radius: Style.radiusM
                visible: wallpaperItem.isDirectory
                border.color: wallpaperGridView.currentIndex === index ? Color.mHover : Color.mSurface
                border.width: Math.max(1, Style.borderL * 1.5)

                ColumnLayout {
                  anchors.centerIn: parent
                  spacing: Style.marginS

                  NIcon {
                    icon: "folder"
                    pointSize: Style.fontSizeXXXL
                    color: Color.mPrimary
                    Layout.alignment: Qt.AlignHCenter
                  }
                }
              }

              // Image display (for non-directories)
              NImageRounded {
                id: img
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                height: imageContainer.imageHeight
                visible: !wallpaperItem.isDirectory
                imagePath: wallpaperItem.cachedPath
                radius: Style.radiusM
                borderColor: {
                  if (wallpaperItem.isSelected) {
                    return Color.mSecondary;
                  }
                  if (wallpaperGridView.currentIndex === index) {
                    return Color.mHover;
                  }
                  return Color.mSurface;
                }
                borderWidth: Math.max(1, Style.borderL * 1.5)
                imageFillMode: Image.PreserveAspectCrop
              }

              // Loading/error state background (for non-directories)
              Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                height: imageContainer.imageHeight
                color: Color.mSurfaceVariant
                radius: Style.radiusM
                visible: !wallpaperItem.isDirectory && (img.status === Image.Loading || img.status === Image.Error || wallpaperItem.cachedPath === "")

                NIcon {
                  icon: "image"
                  pointSize: Style.fontSizeL
                  color: Color.mOnSurfaceVariant
                  anchors.centerIn: parent
                }
              }

              NBusyIndicator {
                anchors.horizontalCenter: parent.horizontalCenter
                y: (imageContainer.imageHeight - height) / 2
                visible: !wallpaperItem.isDirectory && (img.status === Image.Loading || wallpaperItem.cachedPath === "")
                running: visible
                size: 18
              }

              Rectangle {
                anchors.top: parent.top
                anchors.right: parent.right
                anchors.margins: Style.marginS
                width: 28
                height: 28
                radius: width / 2
                z: 6
                color: Color.mSecondary
                border.color: Color.mOutline
                border.width: Style.borderS
                visible: wallpaperItem.isSelected

                NIcon {
                  icon: "check"
                  pointSize: Style.fontSizeM
                  color: Color.mOnSecondary
                  anchors.centerIn: parent
                }

                MouseArea {
                  anchors.fill: parent
                  onClicked: {}
                }
              }

              // Favorite star button (top-left)
              Rectangle {
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.margins: Style.marginS
                width: 28
                height: 28
                radius: width / 2
                visible: !wallpaperItem.isDirectory && (wallpaperItem.isFavorited || hoverHandler.hovered || wallpaperGridView.currentIndex === index)
                color: {
                  if (wallpaperItem.isFavorited)
                    return starHoverHandler.hovered ? Color.mHover : Color.mPrimary;
                  return starHoverHandler.hovered ? Color.mSurfaceVariant : Color.mSurface;
                }
                opacity: wallpaperItem.isFavorited || starHoverHandler.hovered ? 1.0 : 0.7
                z: 11

                Behavior on color {
                  ColorAnimation {
                    duration: Style.animationFast
                  }
                }
                Behavior on opacity {
                  NumberAnimation {
                    duration: Style.animationFast
                  }
                }

                NIcon {
                  icon: wallpaperItem.isFavorited ? "star-filled" : "star"
                  pointSize: Style.fontSizeM
                  color: {
                    if (wallpaperItem.isFavorited)
                      return starHoverHandler.hovered ? Color.mOnHover : Color.mOnPrimary;
                    return starHoverHandler.hovered ? Color.mOnSurface : Color.mOnSurfaceVariant;
                  }
                  anchors.centerIn: parent
                }

                HoverHandler {
                  id: starHoverHandler
                }

                TapHandler {
                  onTapped: {
                    var mon = Settings.data.wallpaper.setWallpaperOnAllMonitors ? undefined : (wallpaperScreenView.targetScreen ? wallpaperScreenView.targetScreen.name : undefined);
                    WallpaperService.toggleFavorite(wallpaperItem.wallpaperPath, WallpaperService.wallpaperSelectionAppearance, mon);
                  }
                }
              }

              // Palette color dots (bottom-center, favorites only) — taps must not fall through to selectItem
              Item {
                id: paletteRow
                anchors.bottom: img.bottom
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottomMargin: Style.marginS
                z: 10
                implicitWidth: paletteRowRow.implicitWidth
                implicitHeight: paletteRowRow.implicitHeight
                width: implicitWidth
                height: implicitHeight
                visible: wallpaperItem.isFavorited && paletteRow.colors.length > 0

                property int diameter: 25 * Style.uiScaleRatio
                property int _favRevision: 0
                property var favData: {
                  _favRevision;
                  WallpaperService.favoritesRevision;
                  Settings.data.wallpaper.linkLightAndDarkWallpapers;
                  return WallpaperService.getFavoriteForDisplay(wallpaperItem.wallpaperPath);
                }
                property var colors: favData && favData.paletteColors ? favData.paletteColors : []
                property bool isDark: {
                  if (!favData) {
                    return false;
                  }
                  if (favData.appearance === "dark") {
                    return true;
                  }
                  if (favData.appearance === "light") {
                    return false;
                  }
                  return favData.darkMode === true;
                }

                Connections {
                  target: WallpaperService
                  function onFavoriteDataUpdated(path) {
                    if (path === wallpaperItem.wallpaperPath)
                      paletteRow._favRevision++;
                  }
                }

                Row {
                  id: paletteRowRow
                  spacing: Style.marginXS

                  // Sun/moon only when light/dark share one wallpaper (which appearance the favorite targets)
                  Rectangle {
                    width: paletteRow.diameter
                    height: paletteRow.diameter
                    radius: width * 0.5
                    visible: Settings.data.wallpaper.linkLightAndDarkWallpapers
                    color: Color.mSurface
                    border.color: Color.mShadow
                    border.width: Style.borderS

                    NIcon {
                      icon: paletteRow.isDark ? "moon" : "sun"
                      pointSize: parent.width * 0.45
                      color: Color.mOnSurface
                      anchors.centerIn: parent
                    }
                  }

                  Repeater {
                    model: paletteRow.colors

                    Rectangle {
                      width: paletteRow.diameter
                      height: paletteRow.diameter
                      radius: width * 0.5
                      color: modelData
                      border.color: Color.mShadow
                      border.width: Style.borderS
                    }
                  }
                }

                TapHandler {
                  onTapped: {}
                }
              }

              Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                height: imageContainer.imageHeight
                color: Color.mSurface
                radius: Style.radiusM
                opacity: (hoverHandler.hovered || wallpaperItem.isSelected || wallpaperGridView.currentIndex === index) ? 0 : 0.3
                Behavior on opacity {
                  NumberAnimation {
                    duration: Style.animationFast
                  }
                }
              }

              HoverHandler {
                id: hoverHandler
              }

              TapHandler {
                onTapped: {
                  wallpaperGridView.forceActiveFocus();
                  wallpaperGridView.currentIndex = index;
                  selectItem(wallpaperItem.wallpaperPath, wallpaperItem.isDirectory);
                }
              }
            }

            NText {
              text: wallpaperItem.filename
              visible: !Settings.data.wallpaper.hideWallpaperFilenames
              color: (hoverHandler.hovered || wallpaperItem.isSelected || wallpaperGridView.currentIndex === index) ? Color.mOnSurface : Color.mOnSurfaceVariant
              pointSize: Style.fontSizeXS
              Layout.fillWidth: true
              Layout.leftMargin: Style.marginS
              Layout.rightMargin: Style.marginS
              Layout.alignment: Qt.AlignHCenter
              horizontalAlignment: Text.AlignHCenter
              elide: Text.ElideRight
            }
          }
        }
      }

      // Empty / scanning state
      Rectangle {
        color: Color.mSurfaceContainer
        radius: Style.radiusM
        border.color: Color.mOutline
        border.width: Style.borderS
        visible: (wallpaperModel.count === 0 && !WallpaperService.scanning) || WallpaperService.scanning
        Layout.fillWidth: true
        Layout.preferredHeight: 130

        ColumnLayout {
          anchors.fill: parent
          visible: WallpaperService.scanning
          NBusyIndicator {
            Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter
          }
        }

        ColumnLayout {
          anchors.fill: parent
          visible: wallpaperModel.count === 0 && !WallpaperService.scanning
          Item {
            Layout.fillHeight: true
          }
          NIcon {
            icon: "folder-open"
            pointSize: Style.fontSizeXXL
            color: Color.mOnSurface
            Layout.alignment: Qt.AlignHCenter
          }
          NText {
            text: (root.filterText && root.filterText.length > 0) ? "No match found." : (isBrowseMode ? "This directory is empty." : "No wallpaper found.")
            color: Color.mOnSurface
            font.weight: Style.fontWeightBold
            Layout.alignment: Qt.AlignHCenter
          }
          NText {
            text: (root.filterText && root.filterText.length > 0) ? "Try a different search query." : (isBrowseMode ? "Use the back button to navigate up." : "Configure your wallpaper directory with images.")
            color: Color.mOnSurfaceVariant
            wrapMode: Text.WordWrap
            Layout.alignment: Qt.AlignHCenter
          }
          Item {
            Layout.fillHeight: true
          }
        }
      }
    }
  }
}
