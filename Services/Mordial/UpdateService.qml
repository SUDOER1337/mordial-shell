pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Services.Mordial
import qs.Services.UI

Singleton {
  id: root

  // Version properties
  readonly property string baseVersion: "4.7.8"
  readonly property bool isDevelopment: true
  readonly property string developmentSuffix: "-git"
  readonly property string currentVersion: `v${!isDevelopment ? baseVersion : baseVersion + developmentSuffix}`

  readonly property string discordUrl: "https://github.com/SUDOER1337/mordial-shell"

  property bool initialized: false

  function init() {
    if (initialized)
      return;

    initialized = true;
    Logger.i("UpdateService", "Version:", root.currentVersion);
  }

  function normalizeVersion(version) {
    if (!version)
      return "";
    return version.startsWith("v") ? version.substring(1) : version;
  }

  function ensureVersionPrefix(version) {
    if (!version)
      return "";
    return version.startsWith("v") ? version : "v" + version;
  }

  function parseVersionParts(version) {
    const clean = normalizeVersion(version);
    if (!clean)
      return [];
    return clean.split(/[^0-9]+/).filter(part => part.length > 0).map(part => parseInt(part));
  }

  function compareVersions(a, b) {
    if (a === b)
      return 0;
    const partsA = parseVersionParts(a);
    const partsB = parseVersionParts(b);
    const length = Math.max(partsA.length, partsB.length);
    for (var i = 0; i < length; i++) {
      const valA = partsA[i] || 0;
      const valB = partsB[i] || 0;
      if (valA > valB)
        return 1;
      if (valA < valB)
        return -1;
    }
    return 0;
  }

  function openDiscord() {
    if (!discordUrl)
      return;
    Quickshell.execDetached(["xdg-open", discordUrl]);
  }
}
