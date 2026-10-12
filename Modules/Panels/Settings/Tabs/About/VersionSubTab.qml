import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Services.Compositor
import qs.Services.Mordial
import qs.Services.System
import qs.Services.UI
import qs.Widgets

ColumnLayout {
  id: root
  opacity: 0

  onSystemInfoLoadingChanged: {
    if (!systemInfoLoading)
      tabAppearAnim.start();
  }

  NumberAnimation on opacity {
    id: tabAppearAnim
    from: 0
    to: 1
    duration: Style.animationSlowest
    easing.type: Easing.OutCubic
    running: false
  }

  property string currentVersion: UpdateService.currentVersion
  property string commitInfo: ""

  readonly property bool isGitVersion: root.currentVersion.endsWith("-git")
  readonly property int gigaB: (1024 * 1024 * 1024)
  readonly property int gigaD: (1000 * 1000 * 1000)

  // System info properties
  property var systemInfo: null
  property bool systemInfoLoading: true
  property bool systemInfoAvailable: true

  spacing: Style.marginL

  function getModule(type) {
    if (!root.systemInfo)
      return null;
    return root.systemInfo.find(m => m.type === type);
  }

  Component.onCompleted: {
    // Check if fastfetch is available before trying to run it
    checkFastfetchProcess.running = true;
    Logger.d("VersionSubTab", "Current version:", root.currentVersion);
    Logger.d("VersionSubTab", "Is git version:", root.isGitVersion);
    // Only fetch commit info for -git versions
    if (root.isGitVersion) {
      // On NixOS, extract commit hash from the store path first
      if (HostService.isNixOS) {
        var shellDir = Quickshell.shellDir || "";
        Logger.d("VersionSubTab", "Component.onCompleted - NixOS detected, shellDir:", shellDir);
        if (shellDir) {
          // Extract commit hash from path like: /nix/store/...-noctalia-shell-2025-11-30_225e6d3/share/noctalia-shell
          // Pattern matches: noctalia-shell-YYYY-MM-DD_<commit_hash>
          var match = shellDir.match(/mordial-shell-\d{4}-\d{2}-\d{2}_([0-9a-f]{7,})/i);
          if (match && match[1]) {
            // Use first 7 characters of the commit hash
            root.commitInfo = match[1].substring(0, 7);
            Logger.d("VersionSubTab", "Component.onCompleted - Extracted commit from NixOS path:", root.commitInfo);
            return;
          } else {
            Logger.d("VersionSubTab", "Component.onCompleted - Could not extract commit from NixOS path, trying fallback");
          }
        }
      }
      fetchGitCommit();
    }
  }

  function fetchGitCommit() {
    var shellDir = Quickshell.shellDir || "";
    Logger.d("VersionSubTab", "fetchGitCommit - shellDir:", shellDir);
    if (!shellDir) {
      Logger.d("VersionSubTab", "fetchGitCommit - Cannot determine shell directory, skipping git commit fetch");
      return;
    }

    gitProcess.workingDirectory = shellDir;
    gitProcess.running = true;
  }

  Process {
    id: gitProcess
    command: ["git", "rev-parse", "--short", "HEAD"]
    running: false

    onExited: function (exitCode) {
      Logger.d("VersionSubTab", "gitProcess - Process exited with code:", exitCode);
      if (exitCode === 0) {
        var gitOutput = stdout.text.trim();
        Logger.d("VersionSubTab", "gitProcess - gitOutput:", gitOutput);
        if (gitOutput) {
          root.commitInfo = gitOutput;
          Logger.d("VersionSubTab", "gitProcess - Set commitInfo to:", root.commitInfo);
        }
      } else {
        Logger.d("VersionSubTab", "gitProcess - Git command failed. Exit code:", exitCode);
      }
    }

    stdout: StdioCollector {}
    stderr: StdioCollector {}
  }

  // Check if fastfetch is available before attempting to run it
  Process {
    id: checkFastfetchProcess
    command: ["sh", "-c", "command -v fastfetch"]
    running: false

    onExited: function (exitCode) {
      if (exitCode === 0) {
        // fastfetch is available, run it
        Logger.d("VersionSubTab", "fastfetch found, running it");
        fastfetchProcess.running = true;
      } else {
        // fastfetch not found, show error state immediately
        Logger.w("VersionSubTab", "fastfetch not found");
        root.systemInfoLoading = false;
        root.systemInfoAvailable = false;
      }
    }

    stdout: StdioCollector {}
    stderr: StdioCollector {}
  }

  Process {
    id: fastfetchProcess
    command: ["fastfetch", "--format", "json", "--config", Quickshell.shellDir + "/Assets/Services/fastfetch/system-info.jsonc"]
    running: false

    onExited: function (exitCode) {
      root.systemInfoLoading = false;
      if (exitCode === 0) {
        try {
          root.systemInfo = JSON.parse(stdout.text);
          root.systemInfoAvailable = true;
        } catch (e) {
          Logger.w("VersionSubTab", "Failed to parse fastfetch JSON: " + e);
          root.systemInfoAvailable = false;
        }
      } else {
        root.systemInfoAvailable = false;
      }
    }

    stdout: StdioCollector {}
    stderr: StdioCollector {}
  }

  // Versions
  GridLayout {
    columns: 2
    rowSpacing: Style.marginXS
    columnSpacing: Style.marginM

    // Installed Version (Shell)
    NText {
      text: "Mordial Shell:"
      color: Color.mOnSurfaceVariant
      Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
    }

    RowLayout {
      spacing: Style.marginS

      NText {
        text: root.currentVersion
        color: Color.mOnSurface
        font.weight: Style.fontWeightBold
      }

      // Git commit in parentheses
      NText {
        id: commitText
        visible: root.isGitVersion
        text: "(" + (root.commitInfo || "Loading...") + ")"
        color: commitMouseArea.containsMouse ? Color.mPrimary : Color.mOnSurfaceVariant
        pointSize: Style.fontSizeXS
        font.underline: commitMouseArea.containsMouse && root.commitInfo

        MouseArea {
          id: commitMouseArea
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: root.commitInfo ? Qt.PointingHandCursor : Qt.ArrowCursor
          onEntered: {
            if (root.commitInfo) {
              TooltipService.show(commitText, "View commit on GitHub");
            }
          }
          onExited: TooltipService.hide()
          onClicked: {
            if (root.commitInfo) {
              Quickshell.execDetached(["xdg-open", "https://github.com/SUDOER1337/mordial-shell/commit/" + root.commitInfo]);
            }
          }
        }
      }
    }
  }

  // System Information Section
  NDivider {
    Layout.fillWidth: true
  }

  NHeader {
    label: "System Information"
  }

  // Error state (fastfetch not installed)
  ColumnLayout {
    visible: !root.systemInfoAvailable
    Layout.fillWidth: true
    spacing: Style.marginS

    NText {
      text: "fastfetch is not installed"
      color: Color.mOnSurfaceVariant
    }

    NText {
      text: "Install fastfetch to view system information"
      color: Color.mOnSurfaceVariant
      pointSize: Style.fontSizeXS
    }
  }

  // System info grid
  GridLayout {
    id: sysInfo
    readonly property real textSize: Style.fontSizeS

    visible: root.systemInfoAvailable && root.systemInfo
    Layout.fillWidth: true
    columns: 2
    rowSpacing: Style.marginXS
    columnSpacing: Style.marginM

    // OS
    NText {
      text: "OS:"
      color: Color.mOnSurfaceVariant
      pointSize: sysInfo.textSize
    }
    NText {
      text: {
        const os = root.getModule("OS");
        return os?.result?.prettyName || "N/A";
      }
      color: Color.mOnSurface
      pointSize: sysInfo.textSize
      Layout.fillWidth: true
      wrapMode: Text.Wrap
    }

    // Kernel
    NText {
      text: "Kernel:"
      color: Color.mOnSurfaceVariant
      pointSize: sysInfo.textSize
    }
    NText {
      text: {
        const kernel = root.getModule("Kernel");
        return kernel?.result?.release || "N/A";
      }
      color: Color.mOnSurface
      pointSize: sysInfo.textSize
      Layout.fillWidth: true
      wrapMode: Text.Wrap
    }

    // Host
    NText {
      text: "Host:"
      color: Color.mOnSurfaceVariant
      pointSize: sysInfo.textSize
    }
    NText {
      text: {
        const title = root.getModule("Title");
        return title?.result?.hostName || "N/A";
      }
      color: Color.mOnSurface
      pointSize: sysInfo.textSize
      Layout.fillWidth: true
      wrapMode: Text.Wrap
    }

    // Product name
    NText {
      text: "Product:"
      color: Color.mOnSurfaceVariant
      pointSize: sysInfo.textSize
    }
    NText {
      text: {
        const title = root.getModule("Host");
        return title?.result?.name || "N/A";
      }
      color: Color.mOnSurface
      pointSize: sysInfo.textSize
      Layout.fillWidth: true
      wrapMode: Text.Wrap
    }

    // Board name
    NText {
      text: "Board:"
      color: Color.mOnSurfaceVariant
      pointSize: sysInfo.textSize
    }
    NText {
      text: {
        const title = root.getModule("Board");
        return title?.result?.name || "N/A";
      }
      color: Color.mOnSurface
      pointSize: sysInfo.textSize
      Layout.fillWidth: true
      wrapMode: Text.Wrap
    }

    // Uptime
    NText {
      text: "Uptime:"
      color: Color.mOnSurfaceVariant
      pointSize: sysInfo.textSize
    }
    NText {
      text: {
        const value = root.getModule("Uptime")?.result?.uptime;
        return value ? Time.formatVagueHumanReadableDuration(value / 1000) : "-";
      }
      color: Color.mOnSurface
      pointSize: sysInfo.textSize
      Layout.fillWidth: true
      wrapMode: Text.Wrap
    }

    // CPU
    NText {
      text: "CPU:"
      color: Color.mOnSurfaceVariant
      pointSize: sysInfo.textSize
    }
    NText {
      text: {
        const cpu = root.getModule("CPU");
        if (!cpu?.result)
          return "N/A";
        let cpuText = cpu.result.cpu || "N/A";
        const cores = cpu.result.cores;
        if (cores?.logical) {
          cpuText += " (" + cores.logical + " threads)";
        }
        return cpuText;
      }
      color: Color.mOnSurface
      pointSize: sysInfo.textSize
      Layout.fillWidth: true
      wrapMode: Text.Wrap
    }

    // GPU
    NText {
      text: "GPU:"
      color: Color.mOnSurfaceVariant
      pointSize: sysInfo.textSize
    }
    NText {
      text: {
        const gpu = root.getModule("GPU");
        if (!gpu?.result || !Array.isArray(gpu.result) || gpu.result.length === 0)
          return "N/A";
        return gpu.result.map(g => g.name || "Unknown").join(", ");
      }
      color: Color.mOnSurface
      pointSize: sysInfo.textSize
      Layout.fillWidth: true
      wrapMode: Text.Wrap
    }

    // Memory
    NText {
      text: "Memory:"
      color: Color.mOnSurfaceVariant
      pointSize: sysInfo.textSize
    }
    NText {
      text: {
        const mem = root.getModule("Memory");
        if (!mem?.result)
          return "N/A";
        const used = (mem.result.used / root.gigaB).toFixed(1);
        const total = (mem.result.total / root.gigaB).toFixed(1);
        return used + " GiB / " + total + " GiB";
      }
      color: Color.mOnSurface
      pointSize: sysInfo.textSize
      Layout.fillWidth: true
      wrapMode: Text.Wrap
    }

    // Disk
    NText {
      text: "Disk:"
      color: Color.mOnSurfaceVariant
      pointSize: sysInfo.textSize
    }
    NText {
      text: {
        const disk = root.getModule("Disk");
        if (!disk?.result || !Array.isArray(disk.result) || disk.result.length === 0)
          return "N/A";
        const rootDisk = disk.result.find(d => d.mountpoint === "/");
        if (!rootDisk?.bytes)
          return "N/A";
        const used = (rootDisk.bytes.used / root.gigaD).toFixed(1);
        const total = (rootDisk.bytes.total / root.gigaD).toFixed(1);
        return used + " GB / " + total + " GB" + " (" + rootDisk.filesystem + ")";
      }
      color: Color.mOnSurface
      pointSize: sysInfo.textSize
      Layout.fillWidth: true
      wrapMode: Text.Wrap
    }

    // WM
    NText {
      text: "WM:"
      color: Color.mOnSurfaceVariant
      pointSize: sysInfo.textSize
    }
    NText {
      text: {
        const wm = root.getModule("WM");
        if (!wm?.result)
          return "N/A";
        let wmText = wm.result.prettyName || wm.result.processName || "N/A";
        if (wm.result.protocolName) {
          wmText += " (" + wm.result.protocolName + ")";
        }
        return wmText;
      }
      color: Color.mOnSurface
      pointSize: sysInfo.textSize
      Layout.fillWidth: true
      wrapMode: Text.Wrap
    }

    // Packages
    NText {
      text: "Packages:"
      color: Color.mOnSurfaceVariant
      pointSize: sysInfo.textSize
    }
    NText {
      text: {
        const pkg = root.getModule("Packages");
        if (!pkg?.result)
          return "N/A";
        const result = pkg.result;
        if (result.all) {
          const managers = [];
          if (result.rpm > 0)
            managers.push("rpm: " + result.rpm);
          if (result.pacman > 0)
            managers.push("pacman: " + result.pacman);
          if (result.dpkg > 0)
            managers.push("dpkg: " + result.dpkg);
          if (result.flatpakSystem > 0 || result.flatpakUser > 0) {
            const flatpak = (result.flatpakSystem || 0) + (result.flatpakUser || 0);
            managers.push("flatpak: " + flatpak);
          }
          if (result.snap > 0)
            managers.push("snap: " + result.snap);
          if (result.nixSystem > 0 || result.nixUser > 0 || result.nixDefault > 0) {
            const nix = (result.nixSystem || 0) + (result.nixUser || 0) + (result.nixDefault || 0);
            managers.push("nix: " + nix);
          }
          if (result.brew > 0)
            managers.push("brew: " + result.brew);
          if (managers.length > 0) {
            return result.all + " (" + managers.join(", ") + ")";
          }
          return result.all.toString();
        }
        return "N/A";
      }
      color: Color.mOnSurface
      pointSize: sysInfo.textSize
      Layout.fillWidth: true
      wrapMode: Text.Wrap
    }

    // Monitors (2 items per screen: label + value)
    Repeater {
      model: Quickshell.screens.length * 2

      NText {
        readonly property int screenIndex: Math.floor(index / 2)
        readonly property bool isLabel: index % 2 === 0
        readonly property var screen: Quickshell.screens[screenIndex]

        text: {
          if (isLabel)
            return "Monitor:";
          const name = screen?.name || "Unknown";
          const scales = CompositorService.displayScales || {};
          const scaleData = scales[name];
          const scaleValue = (typeof scaleData === "object" && scaleData !== null) ? (scaleData.scale || 1.0) : (scaleData || 1.0);
          return name + ": " + (screen?.width || 0) + "x" + (screen?.height || 0) + " @ " + scaleValue + "x";
        }
        color: isLabel ? Color.mOnSurfaceVariant : Color.mOnSurface
        pointSize: sysInfo.textSize
        Layout.fillWidth: !isLabel
        wrapMode: Text.Wrap
      }
    }
  }
}
