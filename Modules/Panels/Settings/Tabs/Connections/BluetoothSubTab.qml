import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window
import Quickshell
import Quickshell.Bluetooth

import qs.Commons
import qs.Services.Hardware
import qs.Services.Networking
import qs.Services.System
import qs.Services.UI
import qs.Widgets

Item {
  id: root
  Layout.fillWidth: true
  implicitHeight: mainLayout.implicitHeight

  // Configuration for shared use (e.g. by BluetoothPanel)
  property bool showOnlyLists: false

  readonly property bool isScanningActive: BluetoothService.scanningActive
  readonly property bool isDiscoverable: BluetoothService.discoverable

  // Device lists with local filtering logic
  readonly property var connectedDevices: {
    if (!BluetoothService.adapter || !BluetoothService.adapter.devices)
      return [];
    var filtered = BluetoothService.adapter.devices.values.filter(dev => dev && !dev.blocked && dev.connected);
    filtered = BluetoothService.dedupeDevices(filtered);
    return BluetoothService.sortDevices(filtered);
  }

  readonly property var pairedDevices: {
    if (!BluetoothService.adapter || !BluetoothService.adapter.devices)
      return [];
    var filtered = BluetoothService.adapter.devices.values.filter(dev => dev && !dev.blocked && !dev.connected && (dev.paired || dev.trusted));
    filtered = BluetoothService.dedupeDevices(filtered);
    return BluetoothService.sortDevices(filtered);
  }

  readonly property var unnamedAvailableDevices: {
    if (!BluetoothService.adapter || !BluetoothService.adapter.devices)
      return [];
    return BluetoothService.adapter.devices.values.filter(dev => dev && !dev.blocked && !dev.paired && !dev.trusted);
  }

  readonly property var availableDevices: {
    var list = root.unnamedAvailableDevices;

    if (Settings.data.network.bluetoothHideUnnamedDevices) {
      list = list.filter(function (dev) {
        var dn = dev.name || dev.deviceName || "";
        var s = String(dn).trim();
        if (s.length === 0)
          return false;
        var lower = s.toLowerCase();
        if (lower === "unknown" || lower === "unnamed" || lower === "n/a" || lower === "na")
          return false;
        var addr = dev.address || dev.bdaddr || dev.mac || "";
        if (addr.length > 0) {
          var normName = s.toLowerCase().replace(/[^0-9a-z]/g, "");
          var normAddr = String(addr).toLowerCase().replace(/[^0-9a-z]/g, "");
          if (normName.length > 0 && normName === normAddr)
            return false;
        }
        var macRegexComb = /^(([0-9A-Fa-f]{2}[:\-]){5}[0-9A-Fa-f]{2}|([0-9A-Fa-f]{4}\.){2}[0-9A-Fa-f]{4}|[0-9A-Fa-f]{12})$/;
        if (macRegexComb.test(s)) {
          return false;
        }
        return true;
      });
    }
    list = BluetoothService.dedupeDevices(list);
    return BluetoothService.sortDevices(list);
  }

  // For managing expanded device details
  property string expandedDeviceKey: ""
  property bool detailsGrid: (Settings.data.network.bluetoothDetailsViewMode === "grid")

  // Combined visibility check: tab must be visible AND the window must be visible
  readonly property bool effectivelyVisible: root.visible && Window.window && Window.window.visible

  Connections {
    target: BluetoothService
    function onEnabledChanged() {
      stateChangeDebouncer.restart();
    }
    function onDiscoverableChanged() {
      stateChangeDebouncer.restart();
    }
  }

  onEffectivelyVisibleChanged: stateChangeDebouncer.restart()

  Timer {
    id: stateChangeDebouncer
    interval: 100 // 100ms debounce
    repeat: false
    onTriggered: root._updateScanningState()
  }

  function _updateScanningState() {
    if (effectivelyVisible && BluetoothService.enabled && !showOnlyLists) {
      Logger.d("BluetoothPrefs", "Panel/tab active");
      if (!isScanningActive) {
        BluetoothService.setScanActive(true);
      }
      if (!Settings.data.network.disableDiscoverability && !isDiscoverable) {
        BluetoothService.setDiscoverable(true);
      }
    } else {
      Logger.d("BluetoothPrefs", "Panel/tab inactive");
      if (isScanningActive && !showOnlyLists) {
        BluetoothService.setScanActive(false);
      }
      if (isDiscoverable && !showOnlyLists) {
        BluetoothService.setDiscoverable(false);
      }
    }
  }

  Component.onDestruction: {
    // Ensure scanning is stopped when component is closed
    if (isScanningActive && !showOnlyLists) {
      BluetoothService.setScanActive(false);
    }
    // Ensure discoverable is disabled when component is closed
    if (isDiscoverable && !showOnlyLists) {
      BluetoothService.setDiscoverable(false);
    }
    Logger.d("BluetoothPrefs", "Panel closed");
  }

  ColumnLayout {
    id: mainLayout
    anchors.left: parent.left
    anchors.right: parent.right
    spacing: root.showOnlyLists ? Style.marginM : Style.marginL

    // Master Control Section
    NBox {
      visible: !root.showOnlyLists
      Layout.fillWidth: true
      Layout.preferredHeight: masterControlCol.implicitHeight + Style.margin2L
      color: Color.mSurface

      ColumnLayout {
        id: masterControlCol
        anchors.fill: parent
        anchors.margins: Style.marginL
        spacing: Style.marginM

        RowLayout {
          Layout.fillWidth: true
          spacing: Style.marginM

          NToggle {
            label: "Bluetooth"
            icon: BluetoothService.enabled ? "bluetooth" : "bluetooth-off"
            checked: BluetoothService.enabled
            enabled: !NetworkService.airplaneModeEnabled && BluetoothService.bluetoothAvailable && !BluetoothService.blocked
            onToggled: checked => BluetoothService.setBluetoothEnabled(checked)
            Layout.alignment: Qt.AlignVCenter
          }
        }

        NDivider {
          Layout.fillWidth: true
          visible: BluetoothService.enabled && isDiscoverable
        }

        NText {
          visible: BluetoothService.enabled && isDiscoverable
          Layout.fillWidth: true
          text: "This device is discoverable as <b>" + (HostService.hostName) + "</b> while this settings tab is open."
          color: Color.mOnSurfaceVariant
          richTextEnabled: true
          wrapMode: Text.WordWrap
          horizontalAlignment: Text.AlignHCenter
        }
      }
    }

    Item {
      visible: !showOnlyLists
      Layout.fillWidth: true
    }

    // Device List [1] (Connected)
    NBox {
      id: connectedDevicesBox
      visible: root.connectedDevices.length > 0 && BluetoothService.enabled
      Layout.fillWidth: true
      Layout.preferredHeight: connectedDevicesCol.implicitHeight + Style.margin2M
      border.color: showOnlyLists ? Style.boxBorderColor : "transparent"
      color: showOnlyLists ? Color.mSurfaceVariant : "transparent"

      ColumnLayout {
        id: connectedDevicesCol
        anchors.fill: parent
        anchors.topMargin: Style.marginM
        anchors.bottomMargin: Style.marginM
        anchors.leftMargin: showOnlyLists ? Style.marginL : 0
        anchors.rightMargin: showOnlyLists ? Style.marginL : 0
        spacing: Style.marginM

        NLabel {
          label: "Connected devices"
          Layout.fillWidth: true
          Layout.leftMargin: Style.marginS
        }

        Repeater {
          model: root.connectedDevices
          delegate: nboxDelegate
        }
      }
    }

    // Devices List [2] (Paired)
    NBox {
      id: pairedDevicesBox
      visible: root.pairedDevices.length > 0 && BluetoothService.enabled
      Layout.fillWidth: true
      Layout.preferredHeight: pairedDevicesCol.implicitHeight + Style.margin2M
      border.color: showOnlyLists ? Style.boxBorderColor : "transparent"
      color: showOnlyLists ? Color.mSurfaceVariant : "transparent"

      ColumnLayout {
        id: pairedDevicesCol
        anchors.fill: parent
        anchors.topMargin: Style.marginM
        anchors.bottomMargin: Style.marginM
        anchors.leftMargin: showOnlyLists ? Style.marginL : 0
        anchors.rightMargin: showOnlyLists ? Style.marginL : 0
        spacing: Style.marginM

        NLabel {
          label: "Paired devices"
          Layout.fillWidth: true
          Layout.leftMargin: Style.marginS
        }

        Repeater {
          model: root.pairedDevices
          delegate: nboxDelegate
        }
      }
    }

    // Device List [3] (Available)
    NBox {
      id: availableDevicesBox
      visible: !root.showOnlyLists && root.unnamedAvailableDevices.length > 0 && BluetoothService.enabled
      Layout.fillWidth: true
      Layout.preferredHeight: availableDevicesCol.implicitHeight + Style.margin2M
      border.color: "transparent"
      color: showOnlyLists ? Color.mSurfaceVariant : "transparent"

      ColumnLayout {
        id: availableDevicesCol
        anchors.fill: parent
        anchors.topMargin: Style.marginM
        anchors.bottomMargin: Style.marginM
        spacing: Style.marginM

        RowLayout {
          Layout.fillWidth: true
          Layout.leftMargin: Style.marginS
          spacing: Style.marginS

          NLabel {
            label: "Available devices"
            description: BluetoothService.scanningActive ? "Scanning for devices..." : ""
            Layout.fillWidth: true
          }
        }

        Repeater {
          model: root.availableDevices
          delegate: nboxDelegate
        }

        NText {
          visible: root.availableDevices.length === 0 && root.unnamedAvailableDevices.length > 0
          text: "Unnamed devices are not shown."
          pointSize: Style.fontSizeS
          color: Color.mOnSurfaceVariant
          horizontalAlignment: Text.AlignHCenter
          Layout.fillWidth: true
          Layout.margins: Style.marginL
        }
      }
    }

    Item {
      visible: !showOnlyLists
      Layout.fillWidth: true
    }

    NBox {
      id: miscSettingsBox
      visible: !root.showOnlyLists && BluetoothService.enabled
      Layout.fillWidth: true
      Layout.preferredHeight: miscSettingsCol.implicitHeight + Style.margin2XL
      color: Color.mSurface

      ColumnLayout {
        id: miscSettingsCol
        anchors.fill: parent
        anchors.margins: Style.marginXL
        spacing: Style.marginM

        NToggle {
          label: "Auto-connect paired devices"
          description: "Automatically connect to trusted paired devices when Bluetooth is enabled."
          checked: Settings.data.network.bluetoothAutoConnect
          onToggled: checked => Settings.data.network.bluetoothAutoConnect = checked
        }

        NToggle {
          label: "Hide unnamed devices"
          description: "Hide devices that appear only as Bluetooth addresses."
          checked: Settings.data.network.bluetoothHideUnnamedDevices
          onToggled: checked => Settings.data.network.bluetoothHideUnnamedDevices = checked
        }

        NToggle {
          label: "Disable device visibility"
          description: "Hide your device from nearby Bluetooth devices."
          checked: Settings.data.network.disableDiscoverability
          onToggled: checked => {
                       Settings.data.network.disableDiscoverability = checked;
                       BluetoothService.setDiscoverable(!checked);
                     }
        }

        // RSSI Polling
        NToggle {
          label: "Bluetooth signal polling"
          description: "Periodically sample RSSI for connected devices via bluetoothctl. May not be available for all devices; uses minimal resources when enabled."
          checked: Settings.data.network.bluetoothRssiPollingEnabled
          onToggled: checked => Settings.data.network.bluetoothRssiPollingEnabled = checked
        }
        NSpinBox {
          label: "Polling interval"
          description: "Configure how often to update signal strength for connected devices."
          from: 10000
          to: 120000
          stepSize: 1000
          value: Settings.data.network.bluetoothRssiPollIntervalMs
          defaultValue: Settings.getDefaultValue("network.bluetoothRssiPollIntervalMs")
          onValueChanged: Settings.data.network.bluetoothRssiPollIntervalMs = value
          suffix: " ms"
          Layout.alignment: Qt.AlignVCenter
          visible: Settings.data.network.bluetoothRssiPollingEnabled
        }
      }
    }
  }

  // Shared Delegate
  Component {
    id: nboxDelegate
    NBox {
      id: device

      readonly property bool canConnect: BluetoothService.canConnect(modelData)
      readonly property bool canDisconnect: BluetoothService.canDisconnect(modelData)
      readonly property bool canPair: BluetoothService.canPair(modelData)
      readonly property bool isBusy: BluetoothService.isDeviceBusy(modelData)
      readonly property bool isExpanded: root.expandedDeviceKey === BluetoothService.deviceKey(modelData)

      function getContentColors(defaultColors = [Color.mSurface, Color.mOnSurface]) {
        if (modelData.pairing || modelData.state === BluetoothDeviceState.Connecting) {
          return [Color.mPrimary, Color.mOnPrimary];
        }
        if (modelData.connected && modelData.state !== BluetoothDeviceState.Disconnecting) {
          return [Color.mPrimary, Color.mOnPrimary];
        }
        if (modelData.blocked || modelData.state === BluetoothDeviceState.Disconnecting) {
          return [Color.mError, Color.mOnError];
        }
        return defaultColors;
      }

      Layout.fillWidth: true
      Layout.preferredHeight: deviceColumn.implicitHeight + (Style.marginXL)
      radius: Style.radiusM
      clip: true
      forceOpaque: true
      color: device.getContentColors()[0]

      ColumnLayout {
        id: deviceColumn
        anchors.fill: parent
        anchors.margins: Style.marginM
        spacing: Style.marginS

        RowLayout {
          id: deviceLayout
          Layout.fillWidth: true
          spacing: Style.marginM
          Layout.alignment: Qt.AlignVCenter

          NIcon {
            Layout.alignment: Qt.AlignLeft | Qt.AlignVCenter
            horizontalAlignment: Text.AlignLeft
            icon: BluetoothService.getDeviceIcon(modelData)
            pointSize: Style.fontSizeXXL
            color: device.getContentColors()[1]
          }

          ColumnLayout {
            Layout.fillWidth: true
            spacing: Style.marginXXS

            NText {
              text: modelData.name || modelData.deviceName
              pointSize: Style.fontSizeM
              font.weight: modelData.connected ? Style.fontWeightBold : Style.fontWeightMedium
              elide: Text.ElideRight
              color: device.getContentColors()[1]
              Layout.fillWidth: true
            }

            NText {
              text: {
                const k = BluetoothService.getStatusKey(modelData);
                if (k === "pairing")
                  return "Pairing...";
                if (k === "blocked")
                  return "Blocked";
                if (k === "connecting")
                  return "Connecting...";
                if (k === "disconnecting")
                  return "Disconnecting...";
                return "";
              }
              visible: text !== ""
              pointSize: Style.fontSizeXS
              color: Qt.alpha(device.getContentColors([Color.mSurfaceVariant, Color.mOnSurfaceVariant])[1], Style.opacityHeavy)
            }

            RowLayout {
              visible: modelData.batteryAvailable
              spacing: Style.marginS
              NIcon {
                icon: {
                  var b = BluetoothService.getBatteryPercent(modelData);
                  return BatteryService.getIcon(b !== null ? b : 0, false, false, b !== null);
                }
                pointSize: Style.fontSizeXS
                color: Qt.alpha(device.getContentColors()[1], Style.opacityHeavy)
              }
              NText {
                text: {
                  var b = BluetoothService.getBatteryPercent(modelData);
                  return b === null ? "-" : (b + "%");
                }
                pointSize: Style.fontSizeXS
                color: Qt.alpha(device.getContentColors([Color.mSurfaceVariant, Color.mOnSurfaceVariant])[1], Style.opacityHeavy)
              }
            }
          }

          Item {
            Layout.fillWidth: true
          }

          RowLayout {
            spacing: Style.marginS

            NBusyIndicator {
              visible: isBusy
              running: visible && root.effectivelyVisible
              color: device.getContentColors()[1]
              size: Style.baseWidgetSize * 0.5
            }

            NIconButton {
              visible: modelData.connected && modelData.state !== BluetoothDeviceState.Disconnecting
              icon: "info"
              tooltipText: "Info"
              baseSize: Style.baseWidgetSize * 0.75
              colorBg: Color.mSurfaceVariant
              colorFg: Color.mOnSurface
              colorBorder: "transparent"
              colorBorderHover: "transparent"
              onClicked: {
                const key = BluetoothService.deviceKey(modelData);
                root.expandedDeviceKey = (root.expandedDeviceKey === key) ? "" : key;
              }
            }

            NIconButton {
              visible: !root.showOnlyLists && (modelData.paired || modelData.trusted) && !modelData.connected && !isBusy && !modelData.blocked
              icon: "trash"
              tooltipText: "Unpair"
              baseSize: Style.baseWidgetSize * 0.75
              colorBg: Color.mPrimary
              colorFg: Color.mOnPrimary
              colorBorder: "transparent"
              colorBorderHover: "transparent"
              onClicked: BluetoothService.unpairDevice(modelData)
            }

            NButton {
              id: button
              visible: modelData.state !== BluetoothDeviceState.Connecting && modelData.state !== BluetoothDeviceState.Disconnecting
              enabled: (canConnect || canDisconnect || (root.showOnlyLists ? false : canPair)) && !isBusy
              fontSize: Style.fontSizeS
              backgroundColor: modelData.connected ? Color.mSurfaceVariant : Color.mPrimary
              textColor: modelData.connected ? Color.mOnSurface : Color.mOnPrimary
              text: {
                if (modelData.pairing)
                  return "Pairing...";
                if (modelData.blocked)
                  return "Blocked";
                if (modelData.connected)
                  return "Disconnect";
                if (!root.showOnlyLists && device.canPair)
                  return "Pair";
                return "Connect";
              }
              onClicked: {
                if (modelData.connected) {
                  BluetoothService.disconnectDevice(modelData);
                } else {
                  if (!root.showOnlyLists && device.canPair) {
                    BluetoothService.pairDevice(modelData);
                  } else {
                    BluetoothService.connectDeviceWithTrust(modelData);
                  }
                }
              }
            }
          }
        }

        // Expanded info section
        Rectangle {
          visible: device.isExpanded
          Layout.fillWidth: true
          implicitHeight: infoColumn.implicitHeight + Style.margin2S
          radius: Style.radiusXS
          color: Color.mSurfaceVariant
          border.width: Style.borderS
          border.color: Style.boxBorderColor
          clip: true

          NIconButton {
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.margins: Style.marginS
            icon: root.detailsGrid ? "layout-list" : "layout-grid"
            tooltipText: root.detailsGrid ? "List view" : "Grid view"
            baseSize: Style.baseWidgetSize * 0.65
            onClicked: {
              root.detailsGrid = !root.detailsGrid;
              Settings.data.network.bluetoothDetailsViewMode = root.detailsGrid ? "grid" : "list";
            }
            z: 1
          }

          GridLayout {
            id: infoColumn
            anchors.fill: parent
            anchors.margins: Style.marginS
            flow: root.detailsGrid ? GridLayout.TopToBottom : GridLayout.LeftToRight
            rows: root.detailsGrid ? 3 : 6
            columns: root.detailsGrid ? 2 : 1
            columnSpacing: Style.marginM
            rowSpacing: Style.marginXS

            // --- Item 1: Signal Strength ---
            RowLayout {
              Layout.fillWidth: true
              Layout.preferredWidth: 1
              spacing: Style.marginXS
              NIcon {
                icon: BluetoothService.getSignalIcon(modelData)
                pointSize: Style.fontSizeXS
                color: Color.mOnSurface
              }
              NText {
                text: BluetoothService.getSignalStrength(modelData)
                pointSize: Style.fontSizeXS
                color: Color.mOnSurface
                Layout.fillWidth: true
              }
            }

            // --- Item 2: Battery ---
            RowLayout {
              Layout.fillWidth: true
              Layout.preferredWidth: 1
              spacing: Style.marginXS
              NIcon {
                icon: {
                  var b = BluetoothService.getBatteryPercent(modelData);
                  return BatteryService.getIcon(b !== null ? b : 0, false, false, b !== null);
                }
                pointSize: Style.fontSizeXS
                color: Color.mOnSurface
              }
              NText {
                text: {
                  var b = BluetoothService.getBatteryPercent(modelData);
                  return b === null ? "-" : (b + "%");
                }
                pointSize: Style.fontSizeXS
                color: Color.mOnSurface
                Layout.fillWidth: true
              }
            }
            // --- Item 3: Pair state ---
            RowLayout {
              Layout.fillWidth: true
              Layout.preferredWidth: 1
              spacing: Style.marginXS
              NIcon {
                icon: "link"
                pointSize: Style.fontSizeXS
                color: Color.mOnSurface
              }
              NText {
                text: modelData.paired ? "Yes" : "No"
                pointSize: Style.fontSizeXS
                color: Color.mOnSurface
                Layout.fillWidth: true
              }
            }
            // --- Item 4: Trust state ---
            RowLayout {
              Layout.fillWidth: true
              Layout.preferredWidth: 1
              spacing: Style.marginXS
              NIcon {
                icon: "shield-check"
                pointSize: Style.fontSizeXS
                color: Color.mOnSurface
              }
              NText {
                text: modelData.trusted ? "Yes" : "No"
                pointSize: Style.fontSizeXS
                color: Color.mOnSurface
                Layout.fillWidth: true
              }
            }
            // --- Item 5: Address ---
            RowLayout {
              Layout.fillWidth: true
              Layout.preferredWidth: 1
              spacing: Style.marginXS
              NIcon {
                icon: "hash"
                pointSize: Style.fontSizeXS
                color: Color.mOnSurface
              }
              NText {
                text: modelData.address || "-"
                pointSize: Style.fontSizeXS
                color: Color.mOnSurface
                Layout.fillWidth: true
              }
            }
            // --- Item 6: Auto-connect ---
            RowLayout {
              Layout.fillWidth: true
              Layout.preferredWidth: 1
              Layout.topMargin: -Style.marginXXS
              spacing: Style.marginXS
              visible: Settings.data.network.bluetoothAutoConnect
              NIcon {
                icon: BluetoothService.getDeviceAutoConnect(modelData) ? "repeat" : "repeat-off"
                pointSize: Style.fontSizeXS
              }
              NCheckbox {
                label: "Auto-connect"
                labelSize: Style.fontSizeXS
                baseSize: Style.baseWidgetSize * 0.5
                checked: BluetoothService.getDeviceAutoConnect(modelData)
                onToggled: checked => BluetoothService.setDeviceAutoConnect(modelData, checked)
              }
            }
          }
        }
      }
    }
  }

  // PIN Authentication Overlay (This part needs some love :P)
  Rectangle {
    id: pinOverlay
    visible: !root.showOnlyLists && BluetoothService.pinRequired
    anchors.centerIn: parent
    width: Math.min(parent.width * 0.9, 400)
    height: pinCol.implicitHeight + Style.margin2L
    color: Color.mSurface
    radius: Style.radiusM
    border.color: Style.boxBorderColor
    border.width: Style.borderS
    z: 1000

    MouseArea {
      anchors.fill: parent
      acceptedButtons: Qt.AllButtons
      onClicked: mouse => mouse.accepted = true
      onWheel: wheel => wheel.accepted = true
    }

    ColumnLayout {
      id: pinCol
      anchors.fill: parent
      anchors.margins: Style.marginL
      spacing: Style.marginL

      NIcon {
        icon: "lock"
        pointSize: 48
        color: Color.mPrimary
        Layout.alignment: Qt.AlignHCenter
      }
      NText {
        text: "Authentication required"
        pointSize: Style.fontSizeXL
        font.weight: Style.fontWeightBold
        color: Color.mOnSurface
        horizontalAlignment: Text.AlignHCenter
        Layout.fillWidth: true
      }
      NText {
        text: "Please enter the PIN code displayed on your device."
        pointSize: Style.fontSizeM
        color: Color.mOnSurfaceVariant
        wrapMode: Text.WordWrap
        horizontalAlignment: Text.AlignHCenter
        Layout.fillWidth: true
      }
      NTextInput {
        id: pinInput
        Layout.fillWidth: true
        placeholderText: "123456"
        inputIconName: "key"
        onVisibleChanged: {
          if (visible) {
            text = "";
            inputItem.forceActiveFocus();
          }
        }
        inputItem.onEditingFinished: {
          if (text.length > 0) {
            BluetoothService.submitPin(text);
            text = "";
          }
        }
      }
      RowLayout {
        Layout.alignment: Qt.AlignHCenter
        spacing: Style.marginM
        NButton {
          text: "Cancel"
          icon: "x"
          onClicked: BluetoothService.cancelPairing()
        }
        NButton {
          text: "Confirm"
          icon: "check"
          backgroundColor: Color.mPrimary
          textColor: Color.mOnPrimary
          enabled: pinInput.text.length > 0
          onClicked: {
            BluetoothService.submitPin(pinInput.text);
            pinInput.text = "";
          }
        }
      }
    }
  }
}
