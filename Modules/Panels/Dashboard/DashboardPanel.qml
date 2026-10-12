import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Modules.Cards
import qs.Modules.MainScreen
import qs.Modules.Panels.Dashboard.Pages
import qs.Services.Compositor
import qs.Services.Media
import qs.Services.UI
import qs.Widgets

SmartPanel {
  id: root

  // === CUSTOMIZATION GUIDE ===
  // This file controls the overall Dashboard layout and sizing. The panel is a
  // sidebar rail plus a StackLayout of pages, one per Sidebar entry.
  //
  // KEY SIZING PROPERTIES (see below for exact lines):
  // 1. Panel size           → FIXED, from Settings.data.dashboard.panelWidth /
  //                           panelHeight (Settings > Dashboard > Appearance).
  //                           Both pages share it, so switching tabs never
  //                           resizes the panel. SmartPanel clamps the request
  //                           to the available screen space.
  // 2. Content margins      → contentLayout anchors.margins
  // 3. Sidebar-to-content gap → contentLayout spacing
  // 4. Sidebar sizing       → See Sidebar.qml (line ~50-60)
  // 5. Home arrangement      → homePage GridLayout below (3 columns x 2 rows;
  //                           media and notifications span both rows)
  // 6. Home cell sizing      → Layout.preferredWidth / preferredHeight per card
  // 7. Page content spacing → See individual Page files (MediaPlayerCard.qml, etc.)
  //
  // ADJUSTMENT SCALE REFERENCE:
  // - Style.marginXS = ~4px, marginS = ~8px, marginM = ~12px, marginL = ~16px
  // - Most sizes scale with Style.uiScaleRatio (UI zoom setting)
  //
  // === Tab Enum (matches SettingsPanel.Tab for backward compatibility) ===
  enum Tab {
    About,
    Audio,
    Bar,
    ColorScheme,
    LockScreen,
    Dashboard,
    DesktopWidgets,
    OSD,
    Display,
    Dock,
    General,
    Hooks,
    Idle,
    Launcher,
    Location,
    Connections,
    Notifications,
    Plugins,
    SessionMenu,
    System,
    UserInterface,
    Wallpaper
  }

  // === Page Enum (the Dashboard's own sidebar pages) ===
  // Home is always index 0: it is the fallback for a plain open (bar widget,
  // `qs ipc call dashboard toggle`) and the page a dismissed panel resets to.
  // Nothing remembers the last page across opens - an explicit request always
  // wins, so callers do not have to know which page is currently shown.
  enum Page {
    Home,
    AIChat,
    Wallpaper
  }

  // Page to show. The sidebar drives this, but a caller that opens the panel
  // from the outside (bar widget, settings button, IPC) sets pendingPage first;
  // onOpened then applies it.
  property int currentPage: DashboardPanel.Page.Home
  property int pendingPage: DashboardPanel.Page.Home

  // Pages live inside the panelContent Component, so their ids are not visible
  // from this scope. The component assigns these references on completion.
  property Item homePage: null
  property Item aiChatPage: null
  property Item wallpaperPage: null
  property int pageCount: 0

  // Page resolved for this open, used to size the panel and to forward keys.
  readonly property Item activePage: {
    if (currentPage === DashboardPanel.Page.Wallpaper)
      return wallpaperPage;
    if (currentPage === DashboardPanel.Page.AIChat)
      return aiChatPage;
    return homePage;
  }

  // Positioning
  readonly property string dashboardPosition: Settings.data.dashboard.position

  readonly property bool hasBarOnScreen: {
    var monitors = Settings.data.bar.monitors || [];
    return monitors.length === 0 || monitors.includes(screen?.name);
  }

  readonly property bool shouldCenter: dashboardPosition === "close_to_bar_button" && !hasBarOnScreen

  panelAnchorHorizontalCenter: shouldCenter || (dashboardPosition !== "close_to_bar_button" && (dashboardPosition.endsWith("_center") || dashboardPosition === "center"))
  panelAnchorVerticalCenter: shouldCenter || dashboardPosition === "center"
  panelAnchorLeft: !shouldCenter && dashboardPosition !== "close_to_bar_button" && dashboardPosition.endsWith("_left")
  panelAnchorRight: !shouldCenter && dashboardPosition !== "close_to_bar_button" && dashboardPosition.endsWith("_right")
  panelAnchorBottom: !shouldCenter && dashboardPosition !== "close_to_bar_button" && dashboardPosition.startsWith("bottom_")
  panelAnchorTop: !shouldCenter && dashboardPosition !== "close_to_bar_button" && dashboardPosition.startsWith("top_")

  // === SIZING & SPACING - ADJUST HERE ===
  // The panel has a FIXED size read straight from the dashboard settings. It is
  // deliberately NOT derived from page content: a content-derived size fed the
  // panel width back into the cards, which fought each other over space and
  // moved the panel geometry on every page change. preferredWidth/Height mirror
  // panelContent's values so the size holds even before content is loaded.
  preferredWidth: Settings.data.dashboard.panelWidth
  preferredHeight: Settings.data.dashboard.panelHeight

  onOpened: {
    MediaService.autoSwitchingPaused = true;
    // A page requested while the panel was closed lands here. Page.Home is the
    // default, so a plain open always starts fresh on Home.
    if (currentPage !== pendingPage) {
      setPage(pendingPage);
    } else if (activePage?.onPageShown) {
      activePage.onPageShown();
    }
  }

  onClosed: {
    MediaService.autoSwitchingPaused = false;
    // No memory across opens: a request only survives until the panel closes, so
    // a later plain open (bar widget, `qs ipc call dashboard toggle`) is back
    // on Page.Home.
    pendingPage = DashboardPanel.Page.Home;
  }

  // Switch the sidebar page. Pages with setup work (focus, selection reset) get
  // their onPageShown() hook called. Callers outside the panel may omit the page
  // or pass something non-numeric, so coerce to a real page id: currentPage is
  // an int and QML rejects undefined with "Cannot assign [undefined] to int".
  function setPage(page) {
    const target = Number.isInteger(page) ? page : DashboardPanel.Page.Home;
    if (currentPage === target) {
      if (activePage?.onPageShown)
        activePage.onPageShown();
      return;
    }
    currentPage = target;
    if (activePage?.onPageShown) {
      activePage.onPageShown();
    }
  }

  // Open the panel on a specific page, remembering it for the open in case the
  // panel was closed. This is the entry point DashboardPanelService uses.
  function openPage(page, buttonItem) {
    pendingPage = Number.isInteger(page) ? page : DashboardPanel.Page.Home;
    if (isPanelOpen) {
      setPage(pendingPage);
      return;
    }
    if (Settings.data.dashboard.position === "close_to_bar_button") {
      open(buttonItem);
    } else {
      open();
    }
  }

  // Toggle like openPage, but closes when the panel is already open on the
  // requested page - the behaviour the settings button and bar widget expect.
  function togglePage(page, buttonItem) {
    const target = Number.isInteger(page) ? page : DashboardPanel.Page.Home;
    if (isPanelOpen && currentPage === target) {
      close();
      return;
    }
    openPage(target, buttonItem);
  }

  // SettingsPanel-compatible API — redirects to standalone settings panel
  function openToTab(tab, subTab) {
    SettingsPanelService.openToTab(tab, subTab, root.screen);
  }

  function onEscapePressed() {
    close();
  }

  // The wallpaper page is the only one with keyboard navigation, so its grid
  // handlers are forwarded here (same duck-typing MainScreen uses for panels).
  function onDownPressed() {
    if (activePage?.onDownPressed)
      activePage.onDownPressed();
  }

  function onUpPressed() {
    if (activePage?.onUpPressed)
      activePage.onUpPressed();
  }

  function onLeftPressed() {
    if (activePage?.onLeftPressed)
      activePage.onLeftPressed();
  }

  function onRightPressed() {
    if (activePage?.onRightPressed)
      activePage.onRightPressed();
  }

  function onReturnPressed() {
    if (activePage?.onReturnPressed)
      activePage.onReturnPressed();
  }

  function onEnterPressed() {
    if (activePage?.onEnterPressed) {
      activePage.onEnterPressed();
    } else if (activePage?.onReturnPressed) {
      activePage.onReturnPressed();
    }
  }

  function onTabPressed() {
    if (pageCount > 0)
      setPage((currentPage + 1) % pageCount);
  }

  function onBackTabPressed() {
    if (pageCount > 0)
      setPage((currentPage - 1 + pageCount) % pageCount);
  }

  panelContent: Item {
    id: panelContent

    // Publish page references to the root scope; their ids are not visible there.
    Component.onCompleted: {
      root.homePage = homePage;
      root.aiChatPage = aiChatPage;
      root.wallpaperPage = wallpaperPage;
      root.pageCount = sidebar.tabCount;
    }

    // Fixed panel size, in raw pixels, straight from the settings. Both pages
    // report the same number, so switching pages never changes the panel
    // geometry. SmartPanel clamps this to the available screen width/height.
    readonly property real contentPreferredWidth: Settings.data.dashboard.panelWidth
    readonly property real contentPreferredHeight: Settings.data.dashboard.panelHeight

    RowLayout {
      id: contentLayout
      anchors.fill: parent
      anchors.margins: Style.marginS
      spacing: Style.marginS

      Sidebar {
        id: sidebar
        expanded: false
        currentIndex: root.currentPage
        onTabSelected: index => root.setPage(index)
      }

      // One StackLayout per sidebar page. Because the panel size is fixed, the
      // stack hands every page the same rectangle, so switching pages changes
      // nothing but which page is visible.
      StackLayout {
        id: pageStack
        Layout.fillWidth: true
        Layout.fillHeight: true
        currentIndex: root.currentPage

        // Home, per dashboardlayout.txt - a 3x2 grid:
        //
        //   +---------------+---------------+---------------+
        //   |               |   Calendar    |               |
        //   | Media player  +---------------+ Notification  |
        //   |               |  Widget grid  |               |
        //   +---------------+---------------+---------------+
        //
        // Media and notifications are the outer columns and span both rows, so
        // they get the full panel height. Calendar and the widget grid split the
        // middle column. Because the panel size is fixed (see panelContent), the
        // grid is handed a stable rectangle and no cell can size the panel back.
        GridLayout {
          id: homePage
          columns: 4
          columnSpacing: Style.marginS
          rowSpacing: Style.marginS

          MediaPlayerCard {
            id: mediaCard
            screen: root.screen
            Layout.column: 0
            Layout.row: 0
            Layout.rowSpan: 2
            Layout.fillWidth: true
            Layout.fillHeight: true
            // Width from the card's own cap, not its implicitWidth, so a long
            // track title cannot widen the column and squeeze the middle one.
            Layout.preferredWidth: contentImplicitWidth
          }

          CalendarMonthCard {
            id: calendarCard
            Layout.column: 1
            Layout.row: 0
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.preferredWidth: Math.round(300 * Style.uiScaleRatio)
            Layout.preferredHeight: implicitHeight
          }

          QuickSettingsPage {
            id: quickSettingsPage
            screen: root.screen
            Layout.column: 1
            Layout.row: 1
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.preferredWidth: contentImplicitWidth
            // The page root is a Rectangle, so its implicitHeight is 0. Without
            // this the row would claim no height and the calendar would absorb
            // the whole middle column.
            Layout.preferredHeight: contentImplicitHeight
          }

          NotificationCard {
            id: notificationCard
            Layout.column: 2
            Layout.row: 0
            Layout.rowSpan: 2
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.preferredWidth: 320
          }
        }

        AIChatPage {
          id: aiChatPage
          screen: root.screen
        }

        WallpaperPage {
          id: wallpaperPage
          screen: root.screen
          onCloseRequested: root.close()
        }
      }
    }
  }
}
