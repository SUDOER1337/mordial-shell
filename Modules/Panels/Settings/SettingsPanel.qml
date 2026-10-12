import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Modules.MainScreen
import qs.Services.UI
import qs.Widgets

SmartPanel {
  id: root

  // Tabs enumeration, order is NOT relevant
  enum Tab {
    About,
    AIChat,
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
    SessionMenu,
    System,
    UserInterface,
    Wallpaper
  }

  property int requestedTab: SettingsPanel.Tab.General
  property int requestedSubTab: -1
  property var requestedEntry: null
  // Content state - these are synced with SettingsContent when panel opens
  property int currentTabIndex: 0
  property var tabsModel: []
  property var activeScrollView: null
  // Internal reference to the content (set when panel content loads)
  property var _settingsContent: null

  // Open to a specific tab and optionally a subtab
  function openToTab(tab, subTab) {
    requestedTab = tab !== undefined ? tab : SettingsPanel.Tab.General;
    requestedSubTab = subTab !== undefined ? subTab : -1;
    if (!isPanelOpen)
      open();
  }

  // Scroll functions - delegate to content
  function scrollDown() {
    if (_settingsContent)
      _settingsContent.scrollDown();
  }

  function scrollUp() {
    if (_settingsContent)
      _settingsContent.scrollUp();
  }

  function scrollPageDown() {
    if (_settingsContent)
      _settingsContent.scrollPageDown();
  }

  function scrollPageUp() {
    if (_settingsContent)
      _settingsContent.scrollPageUp();
  }

  // Navigation functions - delegate to content
  function selectNextTab() {
    if (_settingsContent)
      _settingsContent.selectNextTab();
  }

  function selectPreviousTab() {
    if (_settingsContent)
      _settingsContent.selectPreviousTab();
  }

  // Override keyboard handlers from SmartPanel
  function onTabPressed() {
    selectNextTab();
  }

  function onBackTabPressed() {
    selectPreviousTab();
  }

  function onUpPressed() {
    if (_settingsContent && _settingsContent.searchText.trim() !== "")
      _settingsContent.searchSelectPrevious();
    else
      scrollUp();
  }

  function onDownPressed() {
    if (_settingsContent && _settingsContent.searchText.trim() !== "")
      _settingsContent.searchSelectNext();
    else
      scrollDown();
  }

  function onPageUpPressed() {
    scrollPageUp();
  }

  function onPageDownPressed() {
    scrollPageDown();
  }

  function onCtrlJPressed() {
    if (_settingsContent && _settingsContent.searchText.trim() !== "")
      _settingsContent.searchSelectNext();
    else
      scrollDown();
  }

  function onCtrlKPressed() {
    if (_settingsContent && _settingsContent.searchText.trim() !== "")
      _settingsContent.searchSelectPrevious();
    else
      scrollUp();
  }

  preferredWidth: Math.round(840 * Style.uiScaleRatio)
  preferredHeight: Math.round(910 * Style.uiScaleRatio)
  // Always slide from the left edge of the screen
  panelAnchorLeft: true
  panelAnchorVerticalCenter: true
  // When the panel opens, initialize content
  onOpened: {
    if (_settingsContent) {
      if (requestedEntry) {
        _settingsContent.requestedTab = requestedEntry.tab;
        _settingsContent.initialize();
        const entry = requestedEntry;
        requestedEntry = null;
        Qt.callLater(() => {
                       return _settingsContent.navigateToResult(entry);
                     });
      } else {
        _settingsContent.requestedTab = requestedTab;
        if (requestedSubTab >= 0) {
          _settingsContent._pendingSubTab = requestedSubTab;
          requestedSubTab = -1;
        }
        _settingsContent.initialize();
      }
    }
  }

  panelContent: Item {
    id: panelContent

    readonly property bool allowAttach: true

    SettingsContent {
      id: settingsContent

      anchors.fill: parent
      screen: root.screen
      Component.onCompleted: {
        root._settingsContent = settingsContent;
        root.tabsModel = Qt.binding(function () {
          return settingsContent.tabsModel;
        });
        root.currentTabIndex = Qt.binding(function () {
          return settingsContent.currentTabIndex;
        });
        root.activeScrollView = Qt.binding(function () {
          return settingsContent.activeScrollView;
        });
        settingsContent.closeRequested.connect(() => {
                                                 return root.close();
                                               });
      }
    }
  }
}
